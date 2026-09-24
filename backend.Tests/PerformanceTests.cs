using System.Diagnostics;
using System.Security.Claims;
using Xunit.Abstractions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RemesaSmartSV.Controllers;
using RemesaSmartSV.Data;
using RemesaSmartSV.Entities;

namespace backend.Tests;

[Trait("Categoria", "Performance")]
public class PerformanceTests
{
    private const int IdHogar = 42;
    private const int IdUsuario = 7;

    private readonly ITestOutputHelper _output;

    public PerformanceTests(ITestOutputHelper output) => _output = output;

    private static ApplicationDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new ApplicationDbContext(options);
    }

    private static ClaimsPrincipal CrearClaims() => new(new ClaimsIdentity(new[]
    {
        new Claim("idHogar", IdHogar.ToString()),
        new Claim("idUsuario", IdUsuario.ToString())
    }, "Test"));

    private static MovimientosController CrearControllerMovimientos(ApplicationDbContext db) => new(db)
    {
        ControllerContext = new ControllerContext
        {
            HttpContext = new DefaultHttpContext { User = CrearClaims() }
        }
    };

    private static PresupuestosController CrearControllerPresupuestos(ApplicationDbContext db) => new(db)
    {
        ControllerContext = new ControllerContext
        {
            HttpContext = new DefaultHttpContext { User = CrearClaims() }
        }
    };

    private static Categoria CrearCategoria(string nombre, string tipo = "Gasto", int idHogar = IdHogar)
        => new() { IdHogar = idHogar, Nombre = nombre, Tipo = tipo };

    private static Movimiento CrearMovimiento(decimal monto, DateTime fecha, string tipo, int idCategoria, int idHogar = IdHogar)
        => new() { IdHogar = idHogar, IdUsuario = IdUsuario, IdCategoria = idCategoria, Monto = monto, Fecha = fecha, Tipo = tipo };

    private static Presupuesto CrearPresupuesto(decimal monto, DateTime mesAnio, int idCategoria, int idHogar = IdHogar)
        => new() { IdHogar = idHogar, IdCategoria = idCategoria, MontoLimite = monto, MesAnio = mesAnio };

    [Fact]
    public async Task GetMovimientos_ConDosMilRegistros_RespondeEnMenosDeCincoSegundos()
    {
        using var db = CreateDbContext();
        var movimientos = Enumerable.Range(1, 2000)
            .Select(i => CrearMovimiento(i, new DateTime(2026, 1, 1).AddMinutes(i), "Gasto", idCategoria: (i % 5) + 1));
        db.Movimientos.AddRange(movimientos);
        await db.SaveChangesAsync();
        var controller = CrearControllerMovimientos(db);

        var cronometro = Stopwatch.StartNew();
        var result = await controller.GetMovimientos(null, null);
        cronometro.Stop();

        var ok = Assert.IsType<OkObjectResult>(result.Result);
        var lista = Assert.IsAssignableFrom<IEnumerable<Movimiento>>(ok.Value).ToList();
        _output.WriteLine($"GetMovimientos 2000 registros: {cronometro.ElapsedMilliseconds} ms, devolvio {lista.Count}");
        Assert.Equal(2000, lista.Count);
        Assert.True(cronometro.Elapsed < TimeSpan.FromSeconds(5), $"Tardo {cronometro.ElapsedMilliseconds} ms");
    }

    [Fact]
    public async Task GetMovimientos_ConFiltroYDiezMilRegistros_RespondeEnMenosDeCincoSegundos()
    {
        using var db = CreateDbContext();
        var movimientos = Enumerable.Range(1, 10000)
            .Select(i => CrearMovimiento(i, new DateTime(2026, 1, 1).AddMinutes(i), i % 2 == 0 ? "Gasto" : "Ingreso", idCategoria: (i % 5) + 1));
        db.Movimientos.AddRange(movimientos);
        await db.SaveChangesAsync();
        var controller = CrearControllerMovimientos(db);

        var cronometro = Stopwatch.StartNew();
        var result = await controller.GetMovimientos(3, "Gasto");
        cronometro.Stop();

        var ok = Assert.IsType<OkObjectResult>(result.Result);
        var lista = Assert.IsAssignableFrom<IEnumerable<Movimiento>>(ok.Value).ToList();
        _output.WriteLine($"GetMovimientos con filtro sobre 10000 registros: {cronometro.ElapsedMilliseconds} ms, devolvio {lista.Count}");
        Assert.True(lista.Count > 0);
        Assert.All(lista, m => Assert.Equal(3, m.IdCategoria));
        Assert.True(cronometro.Elapsed < TimeSpan.FromSeconds(5), $"Tardo {cronometro.ElapsedMilliseconds} ms");
    }

    [Fact]
    public async Task Create_MilMovimientosSecuenciales_TardaMenosDeDiezSegundos()
    {
        using var db = CreateDbContext();
        db.Categorias.Add(CrearCategoria("Transporte"));
        await db.SaveChangesAsync();
        var categoria = await db.Categorias.SingleAsync();
        var controller = CrearControllerMovimientos(db);

        var cronometro = Stopwatch.StartNew();
        for (int i = 0; i < 1000; i++)
        {
            var resultado = await controller.Create(CrearMovimiento(i + 1, new DateTime(2026, 1, 1).AddMinutes(i), "Gasto", idCategoria: categoria.IdCategoria));
            Assert.IsType<CreatedAtActionResult>(resultado.Result);
        }
        cronometro.Stop();

        _output.WriteLine($"Create x1000 movimientos: {cronometro.ElapsedMilliseconds} ms");
        Assert.Equal(1000, await db.Movimientos.CountAsync());
        Assert.True(cronometro.Elapsed < TimeSpan.FromSeconds(10), $"Tardo {cronometro.ElapsedMilliseconds} ms");
    }

    [Fact]
    public async Task GetPresupuestos_ConDosMilRegistros_RespondeEnMenosDeCincoSegundos()
    {
        using var db = CreateDbContext();
        var presupuestos = Enumerable.Range(1, 2000)
            .Select(i => CrearPresupuesto(i * 10m, new DateTime(2026, 1, 1).AddMonths(i % 24), idCategoria: 1));
        db.Presupuestos.AddRange(presupuestos);
        await db.SaveChangesAsync();
        var controller = CrearControllerPresupuestos(db);

        var cronometro = Stopwatch.StartNew();
        var result = await controller.GetPresupuestos(2026, 9);
        cronometro.Stop();

        var ok = Assert.IsType<OkObjectResult>(result.Result);
        var lista = Assert.IsAssignableFrom<IEnumerable<Presupuesto>>(ok.Value).ToList();
        _output.WriteLine($"GetPresupuestos filtrado sobre 2000 registros: {cronometro.ElapsedMilliseconds} ms, devolvio {lista.Count}");
        Assert.All(lista, p => Assert.Equal(2026, p.MesAnio.Year));
        Assert.All(lista, p => Assert.Equal(9, p.MesAnio.Month));
        Assert.True(cronometro.Elapsed < TimeSpan.FromSeconds(5), $"Tardo {cronometro.ElapsedMilliseconds} ms");
    }
}