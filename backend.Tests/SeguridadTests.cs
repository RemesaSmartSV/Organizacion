using System.ComponentModel.DataAnnotations;
using System.IdentityModel.Tokens.Jwt;
using System.Reflection;
using System.Security.Claims;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;
using RemesaSmartSV.Controllers;
using RemesaSmartSV.Data;
using RemesaSmartSV.DTOs;
using RemesaSmartSV.Entities;
using RemesaSmartSV.Services;

namespace backend.Tests;

public class SeguridadJwtTests
{
    private const string ClaveValida = "clave-de-prueba-para-firmar-tokens-jwt-0123456789";
    private const string ClaveAjena = "clave-ajena-que-no-debe-firmar-9999999999";
    private const string Issuer = "RemesaSmartSV-Test";
    private const string Audience = "RemesaSmartSV-Client";

    private static readonly IConfiguration Config = new ConfigurationBuilder()
        .AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Jwt:Key"] = ClaveValida,
            ["Jwt:Issuer"] = Issuer,
            ["Jwt:Audience"] = Audience
        })
        .Build();

    private static ApplicationDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new ApplicationDbContext(options);
    }

    private static string Token(string clave, string issuer, string audience, DateTime expira, params Claim[] claims)
    {
        var token = new JwtSecurityToken(
            issuer: issuer,
            audience: audience,
            claims: claims.Length > 0 ? claims : new[] { new Claim("idUsuario", "1") },
            expires: expira,
            signingCredentials: new SigningCredentials(
                new SymmetricSecurityKey(Encoding.UTF8.GetBytes(clave)), SecurityAlgorithms.HmacSha256));
        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    private static TokenValidationParameters Parametros(string clave, string issuer, string audience, TimeSpan? clockSkew = null) => new()
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = issuer,
        ValidAudience = audience,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(clave)),
        ClockSkew = clockSkew ?? TimeSpan.Zero
    };

    private static bool Acepta(string token, TokenValidationParameters parametros)
    {
        try
        {
            new JwtSecurityTokenHandler().ValidateToken(token, parametros, out _);
            return true;
        }
        catch (SecurityTokenException)
        {
            return false;
        }
    }

    private static async Task<LoginResponse> RegistrarYLoguearse()
    {
        using var db = CreateDbContext();
        var service = new AuthService(db, Config);
        await service.RegisterAsync(new RegisterRequest("Ana", "ana@example.com", "secreto123", "Familia Ana"));
        return (await service.LoginAsync(new LoginRequest("ana@example.com", "secreto123")))!;
    }

    [Fact]
    public async Task Jwt_EmitidoPorLogin_PasaLaValidacionConIssuerAudienceVigenciaYFirmaCorrectas()
    {
        var login = await RegistrarYLoguearse();

        var principal = new JwtSecurityTokenHandler()
            .ValidateToken(login.Token, Parametros(ClaveValida, Issuer, Audience), out var tokenValidado);

        Assert.Equal(Issuer, tokenValidado.Issuer);
        Assert.Equal("1", principal.FindFirstValue("idUsuario"));
        Assert.Equal("1", principal.FindFirstValue("idHogar"));
    }

    [Fact]
    public async Task Jwt_ElRolDelTokenEsElQueAutorizaLasOperacionesRestringidas()
    {
        var login = await RegistrarYLoguearse();
        var principal = new JwtSecurityTokenHandler()
            .ValidateToken(login.Token, Parametros(ClaveValida, Issuer, Audience), out _);

        var identidad = principal.Identity as ClaimsIdentity;
        var puedeCrearMiembros = identidad!.HasClaim(c => c.Type == ClaimTypes.Role && c.Value == "Admin");

        Assert.True(puedeCrearMiembros);
    }

    [Fact]
    public void Jwt_FirmadoConUnaClaveDistintaEsRechazadoComoTokenFalsificado()
    {
        var falsificado = Token(ClaveAjena, Issuer, Audience, DateTime.UtcNow.AddHours(8),
            new Claim("idUsuario", "999"),
            new Claim("idHogar", "999"),
            new Claim(ClaimTypes.Role, "Admin"));

        Assert.False(Acepta(falsificado, Parametros(ClaveValida, Issuer, Audience)));
    }

    [Fact]
    public async Task Jwt_AlterarElRolYRefirmarConOtraClaveLanzaSecurityTokenException()
    {
        var login = await RegistrarYLoguearse();
        var original = new JwtSecurityTokenHandler().ReadJwtToken(login.Token);
        var alterado = new JwtSecurityToken(
            issuer: Issuer,
            audience: Audience,
            claims: original.Claims.Where(c => c.Type != ClaimTypes.Role).Append(new Claim(ClaimTypes.Role, "Admin")),
            expires: original.ValidTo,
            signingCredentials: new SigningCredentials(
                new SymmetricSecurityKey(Encoding.UTF8.GetBytes(ClaveAjena)), SecurityAlgorithms.HmacSha256));

        Assert.ThrowsAny<SecurityTokenException>(() =>
            new JwtSecurityTokenHandler().ValidateToken(
                new JwtSecurityTokenHandler().WriteToken(alterado), Parametros(ClaveValida, Issuer, Audience), out _));
    }

    [Fact]
    public void Jwt_ConIssuerDistintoEsRechazado()
    {
        var token = Token(ClaveValida, "OtroEmisor", Audience, DateTime.UtcNow.AddHours(8));

        Assert.False(Acepta(token, Parametros(ClaveValida, Issuer, Audience)));
    }

    [Fact]
    public void Jwt_ConAudienceDistintaEsRechazado()
    {
        var token = Token(ClaveValida, Issuer, "OtraAudiencia", DateTime.UtcNow.AddHours(8));

        Assert.False(Acepta(token, Parametros(ClaveValida, Issuer, Audience)));
    }

    [Fact]
    public void Jwt_VencidoEsRechazado()
    {
        var token = Token(ClaveValida, Issuer, Audience, DateTime.UtcNow.AddMinutes(-30));

        Assert.False(Acepta(token, Parametros(ClaveValida, Issuer, Audience)));
    }

    [Fact]
    public async Task Jwt_LaVigenciaEsDeOchoHorasYNoMas()
    {
        var login = await RegistrarYLoguearse();
        var token = new JwtSecurityTokenHandler().ReadJwtToken(login.Token);

        Assert.InRange(token.ValidTo - DateTime.UtcNow, TimeSpan.FromHours(7.9), TimeSpan.FromHours(8));
    }

    [Fact]
    public async Task Jwt_NoIncluyeClaimJtiPorLoQueNoSePuedeRevocarUnTokenIndividualmente()
    {
        var login = await RegistrarYLoguearse();
        var token = new JwtSecurityTokenHandler().ReadJwtToken(login.Token);

        Assert.DoesNotContain(token.Claims, c => c.Type == JwtRegisteredClaimNames.Jti);
    }

    [Fact]
    public void Vuln_SEC07_UnTokenVencidoHaceMenosDeCincoMinutosTodaviaSeAceptaPorElClockSkewPorDefecto()
    {
        var token = Token(ClaveValida, Issuer, Audience, DateTime.UtcNow.AddMinutes(-2));

        Assert.False(Acepta(token, Parametros(ClaveValida, Issuer, Audience, TimeSpan.Zero)));
        Assert.True(Acepta(token, Parametros(ClaveValida, Issuer, Audience, TimeSpan.FromMinutes(5))));
    }
}

public class SeguridadContrasenasTests
{
    private static ApplicationDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new ApplicationDbContext(options);
    }

    private static Usuario CrearUsuario(string nombre, string correo, string contrasena)
    {
        var usuario = new Usuario
        {
            IdHogar = 1,
            Nombre = nombre,
            Correo = correo,
            Rol = "Admin"
        };
        usuario.ContrasenaHash = new PasswordHasher<Usuario>().HashPassword(usuario, contrasena);
        return usuario;
    }

    [Fact]
    public void ContrasenaHash_UsaPbkdf2ConSalYNoContieneLaClaveEnClaro()
    {
        var usuario = CrearUsuario("Ana", "ana@example.com", "secreto123");

        Assert.NotNull(usuario.ContrasenaHash);
        Assert.DoesNotContain("secreto123", usuario.ContrasenaHash);
        Assert.StartsWith("AQ", usuario.ContrasenaHash);
    }

    [Fact]
    public void ContrasenaHash_DosUsuariosConLaMismaClaveTienenHashesDistintosPorLaSal()
    {
        var hasher = new PasswordHasher<Usuario>();
        var usuarioA = CrearUsuario("Ana", "ana@example.com", "misma-clave-123");
        var usuarioB = CrearUsuario("Luis", "luis@example.com", "misma-clave-123");
        var hashA = hasher.HashPassword(usuarioA, "misma-clave-123");
        var hashB = hasher.HashPassword(usuarioB, "misma-clave-123");

        Assert.NotEqual(hashA, hashB);
        Assert.Equal(PasswordVerificationResult.Success, hasher.VerifyHashedPassword(usuarioA, hashA, "misma-clave-123"));
        Assert.Equal(PasswordVerificationResult.Success, hasher.VerifyHashedPassword(usuarioB, hashB, "misma-clave-123"));
    }

    [Fact]
    public async Task ContrasenaHash_LaVerificacionRechazaLaClaveIncorrecta()
    {
        using var db = CreateDbContext();
        var usuario = CrearUsuario("Ana", "ana@example.com", "secreto123");
        db.Usuarios.Add(usuario);
        await db.SaveChangesAsync();

        var resultado = new PasswordHasher<Usuario>()
            .VerifyHashedPassword(usuario, usuario.ContrasenaHash, "clave-mala");

        Assert.Equal(PasswordVerificationResult.Failed, resultado);
    }

    [Fact]
    public void ContrasenaHash_NuncaSeSerializaEnLasRespuestasJsonDeLaApi()
    {
        var json = JsonSerializer.Serialize(CrearUsuario("Ana", "ana@example.com", "secreto123"));

        Assert.DoesNotContain("ContrasenaHash", json, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("AQAAAA", json, StringComparison.Ordinal);
    }

    [Fact]
    public async Task LoginResponse_NoExponeLaContrasenaNiElHashEnNingunCampo()
    {
        using var db = CreateDbContext();
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Jwt:Key"] = "clave-de-prueba-para-firmar-tokens-jwt-0123456789",
                ["Jwt:Issuer"] = "RemesaSmartSV-Test",
                ["Jwt:Audience"] = "RemesaSmartSV-Client"
            })
            .Build();
        var service = new AuthService(db, config);
        await service.RegisterAsync(new RegisterRequest("Ana", "ana@example.com", "secreto123", "Familia Ana"));

        var login = await service.LoginAsync(new LoginRequest("ana@example.com", "secreto123"));
        var json = JsonSerializer.Serialize(login);

        Assert.NotNull(login);
        Assert.DoesNotContain("secreto123", json);
        Assert.DoesNotContain("AQAAAA", json, StringComparison.Ordinal);
    }
}

public class SeguridadAutorizacionTests
{
    private const int IdHogar = 42;
    private const int IdUsuario = 7;

    private static ApplicationDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new ApplicationDbContext(options);
    }

    private static ClaimsPrincipal Usuario(string rol, int idHogar = IdHogar, int idUsuario = IdUsuario)
        => new(new ClaimsIdentity(new[]
        {
            new Claim("idHogar", idHogar.ToString()),
            new Claim("idUsuario", idUsuario.ToString()),
            new Claim(ClaimTypes.Role, rol)
        }, "Test"));

    private static T ControllerCon<T>(ApplicationDbContext db, ClaimsPrincipal usuario) where T : ControllerBase
    {
        var controller = (T)Activator.CreateInstance(typeof(T), db)!;
        controller.ControllerContext = new ControllerContext
        {
            HttpContext = new DefaultHttpContext { User = usuario }
        };
        return controller;
    }

    private static IReadOnlyList<Type> Controladores() => typeof(AuthController).Assembly
        .GetTypes()
        .Where(t => t.Namespace == "RemesaSmartSV.Controllers" && t.Name.EndsWith("Controller"))
        .OrderBy(t => t.Name)
        .ToList();

    private static readonly string[] AtributosHttp =
    {
        "HttpGetAttribute", "HttpPostAttribute", "HttpPutAttribute", "HttpDeleteAttribute", "HttpPatchAttribute"
    };

    private static IEnumerable<(Type Controller, MethodInfo Metodo)> Endpoints() => Controladores()
        .SelectMany(c => c.GetMethods(BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly)
            .Where(m => m.GetCustomAttributes().Any(a => AtributosHttp.Contains(a.GetType().Name)))
            .Select(m => (c, m)));

    [Fact]
    public void Autorizacion_TodoControllerSinAuthorizeDeClaseExponeSoloEndpointsDeclaradosDeFormaExplicita()
    {
        var controllersSinAuthorizeDeClase = Controladores()
            .Where(c => c.GetCustomAttribute<AuthorizeAttribute>() is null)
            .ToList();

        Assert.Equal(new[] { "AuthController", "TipsFinancierosController" },
            controllersSinAuthorizeDeClase.Select(c => c.Name).ToArray());

        foreach (var controller in controllersSinAuthorizeDeClase)
        {
            var endpoints = controller.GetMethods(BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly)
                .Where(m => m.GetCustomAttributes().Any(a => AtributosHttp.Contains(a.GetType().Name)))
                .ToList();

            Assert.All(endpoints, m => Assert.True(
                m.GetCustomAttribute<AllowAnonymousAttribute>() is not null || m.GetCustomAttribute<AuthorizeAttribute>() is not null,
                $"{controller.Name}.{m.Name} no declara [AllowAnonymous] ni [Authorize] y su controller tampoco tiene [Authorize] de clase."));
        }
    }

    [Fact]
    public void Autorizacion_LosEndpointsPublicosSonSoloLosDelLoginYRegistroYLosTipsDeLectura()
    {
        var publicos = Endpoints()
            .Where(e => e.Metodo.GetCustomAttribute<AllowAnonymousAttribute>() is not null)
            .Where(e => e.Metodo.GetCustomAttribute<AuthorizeAttribute>() is null)
            .Select(e => $"{e.Controller.Name}.{e.Metodo.Name}")
            .OrderBy(n => n)
            .ToList();

        Assert.Equal(
            new[] { "AuthController.Login", "AuthController.Register", "TipsFinancierosController.GetTip", "TipsFinancierosController.GetTips" },
            publicos);
    }

    [Fact]
    public void Autorizacion_NingunEndpointQuedaAnonimoPorHerenciaOErrorDeOmision()
    {
        var endpointsSinProteccion = Endpoints()
            .Where(e => e.Metodo.GetCustomAttribute<AllowAnonymousAttribute>() is null)
            .Where(e => e.Metodo.GetCustomAttribute<AuthorizeAttribute>() is null
                        && e.Controller.GetCustomAttribute<AuthorizeAttribute>() is null)
            .Select(e => $"{e.Controller.Name}.{e.Metodo.Name}")
            .ToList();

        Assert.Empty(endpointsSinProteccion);
    }

    [Fact]
    public void Autorizacion_LasOperacionesCriticasDeUsuariosTipsYHogaresExigenRolAdmin()
    {
        var objetivo = new[]
        {
            "UsuariosController.AddMember", "UsuariosController.Update", "UsuariosController.Delete",
            "TipsFinancierosController.Create", "TipsFinancierosController.Update", "TipsFinancierosController.Delete",
            "HogaresController.Delete"
        };

        var sinRestriccion = objetivo
            .Where(nombre => Roles(nombre) is not (null or "Admin"))
            .ToList();

        Assert.Empty(sinRestriccion);

        string? Roles(string nombre)
        {
            var separacion = nombre.LastIndexOf('.');
            var controller = typeof(AuthController).Assembly.GetType($"RemesaSmartSV.Controllers.{nombre[..separacion]}");
            return controller?.GetMethod(nombre[(separacion + 1)..])?.GetCustomAttribute<AuthorizeAttribute>()?.Roles;
        }
    }

    [Fact]
    public async Task Autorizacion_ElHogarYElUsuarioDeUnMovimientoSeTomanDelTokenYNoDelCuerpo()
    {
        using var db = CreateDbContext();
        db.Categorias.Add(new Categoria { IdHogar = IdHogar, Nombre = "Comida", Tipo = "Gasto" });
        await db.SaveChangesAsync();
        var controller = ControllerCon<MovimientosController>(db, Usuario("Miembro"));

        await controller.Create(new Movimiento
        {
            IdHogar = 999,
            IdUsuario = 999,
            IdCategoria = 1,
            Monto = 10m,
            Fecha = new DateTime(2026, 3, 1),
            Tipo = "Gasto",
            Descripcion = "Prueba de mass assignment"
        });

        var guardado = await db.Movimientos.SingleAsync();
        Assert.Equal(IdHogar, guardado.IdHogar);
        Assert.Equal(IdUsuario, guardado.IdUsuario);
    }

    [Fact]
    public async Task Autorizacion_UnaCategoriaNoPuedeCrearseEnElHogarDeOtroUsuarioAunqueVengaEnElCuerpo()
    {
        using var db = CreateDbContext();
        var controller = ControllerCon<CategoriasController>(db, Usuario("Miembro"));

        await controller.Create(new Categoria { IdHogar = 999, Nombre = "Robada", Tipo = "Gasto" });

        Assert.Equal(IdHogar, (await db.Categorias.SingleAsync()).IdHogar);
    }

    [Fact]
    public async Task Autorizacion_UnMiembroNoCumpleElAtributoAdminParaCrearUsuarios()
    {
        using var db = CreateDbContext();
        var controller = ControllerCon<UsuariosController>(db, Usuario("Miembro"));
        var atributo = typeof(UsuariosController).GetMethod(nameof(UsuariosController.AddMember))!
            .GetCustomAttribute<AuthorizeAttribute>();
        var identidad = Usuario("Miembro").Identity as ClaimsIdentity;

        var autorizado = atributo is not null
            && (string.IsNullOrEmpty(atributo.Roles)
                || identidad!.Claims.Any(c => atributo.Roles.Split(',').Select(r => r.Trim()).Contains(c.Value)));

        Assert.False(autorizado);
        Assert.Equal(0, await db.Usuarios.CountAsync());
    }

    [Fact]
    public async Task Vuln_SEC06_UpdateUsuarioPersisteUnRolFueraDeLaListaAdminMiembro()
    {
        using var db = CreateDbContext();
        var objetivo = new Usuario { IdHogar = IdHogar, Nombre = "Luis", Correo = "luis@example.com", Rol = "Miembro" };
        objetivo.ContrasenaHash = new PasswordHasher<Usuario>().HashPassword(objetivo, "secreto123");
        db.Usuarios.Add(objetivo);
        await db.SaveChangesAsync();
        var controller = ControllerCon<UsuariosController>(db, Usuario("Admin"));

        await controller.Update(objetivo.IdUsuario, new UpdateUsuarioRequest(Nombre: null, Rol: "SuperAdmin"));

        Assert.Equal("SuperAdmin", (await db.Usuarios.SingleAsync()).Rol);
    }

    [Fact]
    public async Task Vuln_SEC06_AddMemberAceptaElRolIndicadoSinValidarContraLaListaAdminMiembro()
    {
        using var db = CreateDbContext();
        var controller = ControllerCon<UsuariosController>(db, Usuario("Admin"));

        var resultado = await controller.AddMember(new AddMemberRequest("Nueva", "nueva@example.com", "secreto123", "Root"));

        Assert.IsType<CreatedAtActionResult>(resultado.Result);
        Assert.Equal("Root", (await db.Usuarios.SingleAsync()).Rol);
    }
}

public class SeguridadXssTests
{
    private const int IdHogar = 42;
    private const string PayloadXss = "<script>alert('xss')</script>";

    private static ApplicationDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new ApplicationDbContext(options);
    }

    private static T ControllerCon<T>(ApplicationDbContext db) where T : ControllerBase
    {
        var controller = (T)Activator.CreateInstance(typeof(T), db)!;
        controller.ControllerContext = new ControllerContext
        {
            HttpContext = new DefaultHttpContext
            {
                User = new ClaimsPrincipal(new ClaimsIdentity(new[]
                {
                    new Claim("idHogar", IdHogar.ToString()),
                    new Claim("idUsuario", "7"),
                    new Claim(ClaimTypes.Role, "Miembro")
                }, "Test"))
            }
        };
        return controller;
    }

    [Fact]
    public async Task Xss_LaDescripcionYElOrigenDeUnMovimientoSeGuardanYSeDevuelvenSinTransformar()
    {
        using var db = CreateDbContext();
        db.Categorias.Add(new Categoria { IdHogar = IdHogar, Nombre = "Comida", Tipo = "Gasto" });
        await db.SaveChangesAsync();
        var controller = ControllerCon<MovimientosController>(db);

        await controller.Create(new Movimiento
        {
            IdCategoria = 1,
            Monto = 5m,
            Fecha = new DateTime(2026, 3, 1),
            Tipo = "Gasto",
            Descripcion = PayloadXss,
            OrigenEmisora = "<img src=x onerror=alert(1)>"
        });

        var guardado = await db.Movimientos.SingleAsync();
        Assert.Equal(PayloadXss, guardado.Descripcion);
        Assert.Equal("<img src=x onerror=alert(1)>", guardado.OrigenEmisora);
    }

    [Fact]
    public void Xss_ElSerializadorJsonDeLaApiEscapaLosCaracteresHtmlDeLosCamposDeTexto()
    {
        var json = JsonSerializer.Serialize(new { descripcion = PayloadXss });

        Assert.DoesNotContain("<script>", json, StringComparison.Ordinal);
        Assert.Contains("\\u003C", json, StringComparison.Ordinal);
    }

    [Fact]
    public async Task Xss_LosTipsSeDevuelvenComoDatosJsonYElBackendNoGeneraHtml()
    {
        using var db = CreateDbContext();
        db.TipsFinancieros.Add(new EducacionFinanciera { IdCategoria = 1, Titulo = "Ahorro", Contenido = PayloadXss });
        await db.SaveChangesAsync();
        var controller = ControllerCon<TipsFinancierosController>(db);

        var resultado = await controller.GetTips();

        var ok = Assert.IsType<OkObjectResult>(resultado.Result);
        var tip = Assert.IsAssignableFrom<IEnumerable<EducacionFinanciera>>(ok.Value).Single();
        Assert.Equal(PayloadXss, tip.Contenido);
        Assert.DoesNotContain("<html", tip.Contenido, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Vuln_SEC05_ElContenidoDeLosTipsNoTieneLimiteDeLongitudNiValidacionDeContenido()
    {
        var propiedad = typeof(EducacionFinanciera).GetProperty(nameof(EducacionFinanciera.Contenido))!;
        var longitudMaxima = propiedad.GetCustomAttribute<StringLengthAttribute>()?.MaximumLength
            ?? propiedad.GetCustomAttribute<MaxLengthAttribute>()?.Length;

        Assert.Null(longitudMaxima);
    }

    [Fact]
    public void Xss_LosCamposDeTextoConLengthLimitanLoQueSePuedePersistirEnElPayload()
    {
        var longitudDeDescripcion = typeof(Movimiento).GetProperty(nameof(Movimiento.Descripcion))!
            .GetCustomAttribute<StringLengthAttribute>()?.MaximumLength;

        Assert.Equal(255, longitudDeDescripcion);
    }
}

public class SeguridadConfiguracionTests
{
    [Fact]
    public void Configuracion_LaValidacionDelJwtExigeIssuerAudienceVigenciaYClaveDeFirma()
    {
        var programCs = SeguridadArchivos.Backend("Program.cs");

        Assert.Contains("ValidateIssuer = true", programCs, StringComparison.Ordinal);
        Assert.Contains("ValidateAudience = true", programCs, StringComparison.Ordinal);
        Assert.Contains("ValidateLifetime = true", programCs, StringComparison.Ordinal);
        Assert.Contains("ValidateIssuerSigningKey = true", programCs, StringComparison.Ordinal);
        Assert.Contains("HmacSha256", SeguridadArchivos.Backend("Services/AuthService.cs"), StringComparison.Ordinal);
    }

    [Fact]
    public void Configuracion_LaValidacionOcurreAntesDeAutorizarYAntesDeMapearLosControllers()
    {
        var programCs = SeguridadArchivos.Backend("Program.cs");

        Assert.True(programCs.IndexOf("app.UseAuthentication()", StringComparison.Ordinal)
            < programCs.IndexOf("app.UseAuthorization()", StringComparison.Ordinal));
        Assert.True(programCs.IndexOf("app.UseAuthorization()", StringComparison.Ordinal)
            < programCs.IndexOf("app.MapControllers()", StringComparison.Ordinal));
    }

    [Fact]
    public void Configuracion_CorsSoloPermiteElOrigenDelFrontendSinWildcardNiCredenciales()
    {
        var programCs = SeguridadArchivos.Backend("Program.cs");

        Assert.Contains("WithOrigins(\"http://localhost:5173\")", programCs, StringComparison.Ordinal);
        Assert.DoesNotContain("AllowAnyOrigin", programCs, StringComparison.Ordinal);
        Assert.DoesNotContain("SetIsOriginAllowed", programCs, StringComparison.Ordinal);
        Assert.DoesNotContain("AllowCredentials", programCs, StringComparison.Ordinal);
    }

    [Fact]
    public void Configuracion_LaApiUsaBearerYNoCookiesPorLoQueElCsrfNoEsExplotable()
    {
        var programCs = SeguridadArchivos.Backend("Program.cs");
        var csproj = SeguridadArchivos.Backend("RemesaSmartSV.csproj");

        Assert.Contains("AddJwtBearer", programCs, StringComparison.Ordinal);
        Assert.DoesNotContain("AddCookie", programCs, StringComparison.Ordinal);
        Assert.DoesNotContain("Antiforgery", programCs, StringComparison.Ordinal);
        Assert.DoesNotContain("Antiforgery", csproj, StringComparison.Ordinal);
    }

    [Fact]
    public void Configuracion_ElAccesoADatosUsaEFCoreConConsultasParametrizadas()
    {
        var fuentes = SeguridadArchivos.BackendTodos("Controllers");
        var servicios = SeguridadArchivos.BackendTodos("Services");

        Assert.NotEmpty(fuentes);
        Assert.All(fuentes, linea => Assert.DoesNotContain("FromSqlRaw", linea, StringComparison.Ordinal));
        Assert.All(fuentes, linea => Assert.DoesNotContain("ExecuteSqlRaw", linea, StringComparison.Ordinal));
        Assert.All(servicios, linea => Assert.DoesNotContain("FromSqlRaw", linea, StringComparison.Ordinal));
    }

    [Fact]
    public void Vuln_SEC01_LaClaveFirmanteDelJwtEstaEnTextoPlanoEnElAppsettingsVersionado()
    {
        using var documento = JsonDocument.Parse(SeguridadArchivos.Backend("appsettings.json"));
        var clave = documento.RootElement.GetProperty("Jwt").GetProperty("Key").GetString();

        Assert.False(string.IsNullOrWhiteSpace(clave));
        Assert.StartsWith("RemesaSmartSV_Clave_Dev", clave);
    }

    [Fact]
    public void Vuln_SEC02_LaContrasenaDePostgresEstaEnTextoPlanoEnElComposeYSeReutilizaEnLaApi()
    {
        var compose = SeguridadArchivos.Backend("docker-compose.yml");

        Assert.Contains("POSTGRES_PASSWORD: SecretPassword123!", compose, StringComparison.Ordinal);
        Assert.Contains("Password=SecretPassword123!", compose, StringComparison.Ordinal);
        Assert.Contains("\"5432:5432\"", compose, StringComparison.Ordinal);
    }

    [Fact]
    public void Vuln_SEC03_NoHayNingunaCabeceraDeSeguridadConfiguradaEnElBackend()
    {
        var programCs = SeguridadArchivos.Backend("Program.cs");

        Assert.DoesNotContain("X-Content-Type-Options", programCs, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("Content-Security-Policy", programCs, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("X-Frame-Options", programCs, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("Referrer-Policy", programCs, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("Permissions-Policy", programCs, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("UseHsts", programCs, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Vuln_SEC04_NoHayLimiteDePeticionesNiBloqueoDeCuentaEnElLogin()
    {
        var programCs = SeguridadArchivos.Backend("Program.cs");
        var authService = SeguridadArchivos.Backend("Services/AuthService.cs");
        var csproj = SeguridadArchivos.Backend("RemesaSmartSV.csproj");

        Assert.DoesNotContain("AddRateLimiter", programCs, StringComparison.Ordinal);
        Assert.DoesNotContain("RequireRateLimiting", programCs, StringComparison.Ordinal);
        Assert.DoesNotContain("Lockout", programCs, StringComparison.Ordinal);
        Assert.DoesNotContain("IntentosFallidos", authService, StringComparison.Ordinal);
        Assert.DoesNotContain("RateLimiting", csproj, StringComparison.Ordinal);
    }

    [Fact]
    public void Vuln_SEC08_ElComposeArrancaLaApiEnDevelopmentExpuestoASwaggerYAlDetalleDeErrores()
    {
        var compose = SeguridadArchivos.Backend("docker-compose.yml");
        var programCs = SeguridadArchivos.Backend("Program.cs");

        Assert.Contains("ASPNETCORE_ENVIRONMENT=Development", compose, StringComparison.Ordinal);
        Assert.Contains("if (app.Environment.IsDevelopment())", programCs, StringComparison.Ordinal);
        Assert.Contains("app.UseSwagger()", programCs, StringComparison.Ordinal);
    }

    [Fact]
    public void Vuln_SEC09_ElContenedorSirveLaApiPorHttpSinTlsYLaBaseDeDatosQuedaExpuestaAlHost()
    {
        var dockerfile = SeguridadArchivos.Backend("Dockerfile");
        var compose = SeguridadArchivos.Backend("docker-compose.yml");

        Assert.Contains("ENV ASPNETCORE_URLS=http://+:8080", dockerfile, StringComparison.Ordinal);
        Assert.Contains("\"8080:8080\"", compose, StringComparison.Ordinal);
        Assert.Contains("UseHttpsRedirection", SeguridadArchivos.Backend("Program.cs"), StringComparison.Ordinal);
    }

    [Fact]
    public void Vuln_SEC10_ElPipelineDeNoEscaneaSecretosYLaApiAceptaTodosLosHostHeader()
    {
        var ci = SeguridadArchivos.Backend(Path.Combine(".github", "workflows", "ci.yml"));
        using var documento = JsonDocument.Parse(SeguridadArchivos.Backend("appsettings.json"));
        var allowedHosts = documento.RootElement.GetProperty("AllowedHosts").GetString();

        Assert.DoesNotContain("gitleaks", ci, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("trufflehog", ci, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("dotnet test", ci, StringComparison.OrdinalIgnoreCase);
        Assert.Equal("*", allowedHosts);
    }

    [Fact]
    public void Vuln_SEC10_LaValidacionDeModeloImplicitaEstaDesactivadaEnLosControllers()
    {
        Assert.Contains("SuppressImplicitRequiredAttributeForNonNullableReferenceTypes = true",
            SeguridadArchivos.Backend("Program.cs"), StringComparison.Ordinal);
    }
}

public static class SeguridadArchivos
{
    public static string Backend(string rutaRelativa) => Leer(Path.Combine("backend", rutaRelativa));

    public static string[] BackendTodos(string carpeta) => Directory
        .GetFiles(Raiz(), $"backend/{carpeta}/*.cs", SearchOption.AllDirectories)
        .Select(File.ReadAllText)
        .ToArray();

    private static string Leer(string rutaRelativa) => File.ReadAllText(Path.Combine(Raiz(), rutaRelativa));

    private static string Raiz()
    {
        var directorio = new DirectoryInfo(AppContext.BaseDirectory);
        while (directorio is not null && !File.Exists(Path.Combine(directorio.FullName, "backend", "appsettings.json")))
            directorio = directorio.Parent;

        return directorio?.FullName
            ?? throw new InvalidOperationException("No se encontro la raiz del repositorio que contiene backend/appsettings.json.");
    }
}
