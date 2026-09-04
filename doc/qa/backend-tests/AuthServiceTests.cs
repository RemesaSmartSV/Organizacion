using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using RemesaSmartSV.Data;
using RemesaSmartSV.DTOs;
using RemesaSmartSV.Entities;
using RemesaSmartSV.Services;

namespace backend.Tests;

public class AuthServiceTests
{
    private readonly IConfiguration _config;

    public AuthServiceTests()
    {
        _config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Jwt:Key"] = "clavesuper-secreta-de-prueba-para-firmar-tokens-jwt-0123456789",
                ["Jwt:Issuer"] = "RemesaSmartSV-Test",
                ["Jwt:Audience"] = "RemesaSmartSV-Client"
            })
            .Build();
    }

    private static ApplicationDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new ApplicationDbContext(options);
    }

    private AuthService CreateService(ApplicationDbContext db) => new(db, _config);

    [Fact]
    public async Task RegisterAsync_ConNuevoCorreo_RegistraHogarYUsuarioAdmin()
    {
        using var db = CreateDbContext();
        var service = CreateService(db);

        var result = await service.RegisterAsync(new RegisterRequest(
            Nombre: "Juan Pérez",
            Correo: "juan@example.com",
            Contrasena: "secreto123",
            NombreFamiliar: "Familia Pérez"));

        Assert.NotNull(result);
        Assert.Equal("juan@example.com", result!.Correo);
        Assert.Equal("Admin", result.Rol);
        Assert.Equal("Juan Pérez", result.Nombre);

        var hogar = await db.Hogares.SingleAsync();
        Assert.Equal("Familia Pérez", hogar.NombreFamiliar);
        Assert.Equal(hogar.IdHogar, result.IdHogar);

        var usuario = await db.Usuarios.SingleAsync();
        Assert.Equal("juan@example.com", usuario.Correo);
        Assert.NotEmpty(usuario.ContrasenaHash);
    }

    [Fact]
    public async Task RegisterAsync_ConCorreoDuplicado_SinDiferenciarMayusculas_DevuelveNull()
    {
        using var db = CreateDbContext();
        db.Usuarios.Add(new Usuario
        {
            IdHogar = 1,
            Nombre = "Existente",
            Correo = "DUP@example.com",
            ContrasenaHash = "hash",
            Rol = "Admin"
        });
        await db.SaveChangesAsync();
        var service = CreateService(db);

        var result = await service.RegisterAsync(new RegisterRequest(
            Nombre: "Nuevo",
            Correo: "dup@example.com",
            Contrasena: "secreto123",
            NombreFamiliar: "Familia"));

        Assert.Null(result);
        Assert.Equal(0, await db.Hogares.CountAsync());
        Assert.Equal(1, await db.Usuarios.CountAsync());
    }

    [Fact]
    public async Task RegisterAsync_ConCorreoDuplicado_NoCreaHogarNiUsuario()
    {
        using var db = CreateDbContext();
        db.Usuarios.Add(new Usuario
        {
            IdHogar = 1,
            Nombre = "Existente",
            Correo = "dup@example.com",
            ContrasenaHash = "hash",
            Rol = "Admin"
        });
        await db.SaveChangesAsync();
        var service = CreateService(db);

        var result = await service.RegisterAsync(new RegisterRequest(
            Nombre: "Nuevo",
            Correo: "dup@example.com",
            Contrasena: "secreto123",
            NombreFamiliar: "Familia"));

        Assert.Null(result);
        Assert.Equal(0, await db.Hogares.CountAsync());
        Assert.Equal(1, await db.Usuarios.CountAsync());
    }

    [Fact]
    public async Task RegisterAsync_DevuelveTokenJwtValidoConClaims()
    {
        using var db = CreateDbContext();
        var service = new AuthService(db, _config);

        var result = await service.RegisterAsync(new RegisterRequest(
            Nombre: "Juan Pérez",
            Correo: "juan@example.com",
            Contrasena: "secreto123",
            NombreFamiliar: "Familia Pérez"));

        Assert.NotNull(result);
        var handler = new JwtSecurityTokenHandler();
        var token = handler.ReadJwtToken(result!.Token);

        Assert.Equal("RemesaSmartSV-Test", token.Issuer);
        Assert.Contains("RemesaSmartSV-Client", token.Audiences);
        Assert.Contains(token.Claims, c => c.Type == "idUsuario" && c.Value == result.IdUsuario.ToString());
        Assert.Contains(token.Claims, c => c.Type == "idHogar" && c.Value == result.IdHogar.ToString());
        Assert.Contains(token.Claims, c => c.Type == ClaimTypes.Role && c.Value == "Admin");
        Assert.Contains(token.Claims, c => c.Type == JwtRegisteredClaimNames.Email && c.Value == "juan@example.com");
    }

    [Fact]
    public async Task LoginAsync_ConCredencialesCorrectas_DevuelveToken()
    {
        using var db = CreateDbContext();
        var usuario = new Usuario
        {
            IdHogar = 1,
            Nombre = "Juan Pérez",
            Correo = "juan@example.com",
            Rol = "Admin"
        };
        usuario.ContrasenaHash = new Microsoft.AspNetCore.Identity.PasswordHasher<Usuario>()
            .HashPassword(usuario, "secreto123");
        db.Usuarios.Add(usuario);
        await db.SaveChangesAsync();
        var service = new AuthService(db, _config);

        var result = await service.LoginAsync(new LoginRequest("juan@example.com", "secreto123"));

        Assert.NotNull(result);
        Assert.Equal("juan@example.com", result!.Correo);
        Assert.Equal("Admin", result.Rol);
        Assert.NotEmpty(result.Token);
    }

    [Fact]
    public async Task LoginAsync_ConCorreoInexistente_DevuelveNull()
    {
        using var db = CreateDbContext();
        var service = CreateService(db);

        var result = await service.LoginAsync(new LoginRequest("nadie@example.com", "secreto123"));

        Assert.Null(result);
    }

    [Fact]
    public async Task LoginAsync_ConCorreoEnMinusculasYRegistroEnMayusculas_Autentica()
    {
        using var db = CreateDbContext();
        var usuario = new Usuario
        {
            IdHogar = 1,
            Nombre = "Juan",
            Correo = "JUAN@example.com",
            Rol = "Admin"
        };
        usuario.ContrasenaHash = new Microsoft.AspNetCore.Identity.PasswordHasher<Usuario>()
            .HashPassword(usuario, "secreto123");
        db.Usuarios.Add(usuario);
        await db.SaveChangesAsync();
        var service = new AuthService(db, _config);

        var result = await service.LoginAsync(new LoginRequest("juan@example.com", "secreto123"));

        Assert.NotNull(result);
    }

    [Fact]
    public async Task LoginAsync_ConContrasenaIncorrecta_DevuelveNull()
    {
        using var db = CreateDbContext();
        var usuario = new Usuario
        {
            IdHogar = 1,
            Nombre = "Juan",
            Correo = "juan@example.com",
            Rol = "Admin"
        };
        usuario.ContrasenaHash = new Microsoft.AspNetCore.Identity.PasswordHasher<Usuario>()
            .HashPassword(usuario, "secreto123");
        db.Usuarios.Add(usuario);
        await db.SaveChangesAsync();
        var service = new AuthService(db, _config);

        var result = await service.LoginAsync(new LoginRequest("juan@example.com", "clave-mala"));

        Assert.Null(result);
    }

    [Fact]
    public async Task RegisterAsync_AsignaContrasenaHasheadaNoPlana()
    {
        using var db = CreateDbContext();
        var service = CreateService(db);

        var result = await service.RegisterAsync(new RegisterRequest(
            Nombre: "Juan",
            Correo: "juan@example.com",
            Contrasena: "secreto123",
            NombreFamiliar: "Familia"));

        Assert.NotNull(result);
        var usuario = await db.Usuarios.SingleAsync();
        Assert.NotEqual("secreto123", usuario.ContrasenaHash);
    }
}
