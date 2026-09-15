using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RemesaSmartSV.Controllers;
using RemesaSmartSV.Data;
using RemesaSmartSV.Entities;

namespace backend.Tests;

public class FiltrosPaginacionTests
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
    public async Task GetMovimientos_FiltroCombinadoCategoriaYTipo_DevuelveSoloLaInterseccion()
    {
        using var db = CreateDbContext();
        db.Movimientos.AddRange(
            CrearMovimiento(100m, new DateTime(2026, 1, 3), "Gasto", idCategoria: 1),
            CrearMovimiento(50m, new DateTime(2026, 1, 1), "Ingreso", idCategoria: 1),
            CrearMovimiento(75m, new DateTime(2026, 1, 2), "Gasto", idCategoria: 2));
        await db.SaveChangesAsync();
        var controller = CrearControllerMovimientos(db);

        var result = await controller.GetMovimientos(1, "Gasto");

        var ok = Assert.IsType<OkObjectResult>(result.Result);
        var movimientos = Assert.IsAssignableFrom<IEnumerable<Movimiento>>(ok.Value).ToList();
        Assert.Single(movimientos);
        Assert.Equal(100m, movimientos[0].Monto);
    }

    [Fact]
    public async Task GetMovimientos_FiltroCategoriaInexistente_DevuelveVacio()
    {
        using var db = CreateDbContext();
        db.Movimientos.Add(CrearMovimiento(100m, new DateTime(2026, 1, 3), "Gasto", idCategoria: 1));
        await db.SaveChangesAsync();
        var controller = CrearControllerMovimientos(db);

        var result = await controller.GetMovimientos(999, null);

        var ok = Assert.IsType<OkObjectResult>(result.Result);
        var movimientos = Assert.IsAssignableFrom<IEnumerable<Movimiento>>(ok.Value).ToList();
        Assert.Empty(movimientos);
    }

    [Fact]
    public async Task GetMovimientos_FiltroTipoConEspacios_SeIgnoraYDevuelveTodos()
    {
        using var db = CreateDbContext();
        db.Movimientos.AddRange(
            CrearMovimiento(100m, new DateTime(2026, 1, 3), "Gasto", idCategoria: 1),
            CrearMovimiento(50m, new DateTime(2026, 1, 1), "Ingreso", idCategoria: 1));
        await db.SaveChangesAsync();
        var controller = CrearControllerMovimientos(db);

        var result = await controller.GetMovimientos(null, "   ");

        var ok = Assert.IsType<OkObjectResult>(result.Result);
        var movimientos = Assert.IsAssignableFrom<IEnumerable<Movimiento>>(ok.Value).ToList();
        Assert.Equal(2, movimientos.Count);
    }

    [Fact]
    public async Task GetMovimientos_CienRegistros_SinPaginacionDevuelveTodos()
    {
        using var db = CreateDbContext();
        var movimientos = Enumerable.Range(1, 100)
            .Select(i => CrearMovimiento(i, new DateTime(2026, 1, 1).AddDays(i), "Gasto", idCategoria: 1));
        db.Movimientos.AddRange(movimientos);
        await db.SaveChangesAsync();
        var controller = CrearControllerMovimientos(db);

        var result = await controller.GetMovimientos(null, null);

        var ok = Assert.IsType<OkObjectResult>(result.Result);
        var lista = Assert.IsAssignableFrom<IEnumerable<Movimiento>>(ok.Value).ToList();
        Assert.Equal(100, lista.Count);
        var fechas = lista.Select(m => m.Fecha).ToList();
        for (int i = 0; i < fechas.Count - 1; i++)
            Assert.True(fechas[i] >= fechas[i + 1], "Se esperaba orden por Fecha descendente");
    }

    [Fact]
    public async Task GetPresupuestos_FiltroAnioYMes_DevuelveSoloElMesSolicitado()
    {
        using var db = CreateDbContext();
        db.Presupuestos.AddRange(
            CrearPresupuesto(100m, new DateTime(2026, 9, 1), idCategoria: 1),
            CrearPresupuesto(200m, new DateTime(2026, 9, 15), idCategoria: 1),
            CrearPresupuesto(300m, new DateTime(2026, 10, 1), idCategoria: 2));
        await db.SaveChangesAsync();
        var controller = CrearControllerPresupuestos(db);

        var result = await controller.GetPresupuestos(2026, 9);

        var ok = Assert.IsType<OkObjectResult>(result.Result);
        var presupuestos = Assert.IsAssignableFrom<IEnumerable<Presupuesto>>(ok.Value).ToList();
        Assert.Equal(2, presupuestos.Count);
        Assert.All(presupuestos, p => Assert.Equal(2026, p.MesAnio.Year));
        Assert.All(presupuestos, p => Assert.Equal(9, p.MesAnio.Month));
    }

    [Fact]
    public async Task GetPresupuestos_FiltroSoloAnio_SinMesSeIgnoraYDevuelveTodos()
    {
        using var db = CreateDbContext();
        db.Presupuestos.AddRange(
            CrearPresupuesto(100m, new DateTime(2026, 9, 1), idCategoria: 1),
            CrearPresupuesto(300m, new DateTime(2025, 9, 1), idCategoria: 2));
        await db.SaveChangesAsync();
        var controller = CrearControllerPresupuestos(db);
        int totalEnBd = await db.Presupuestos.CountAsync();

        var result = await controller.GetPresupuestos(2026, null);

        var ok = Assert.IsType<OkObjectResult>(result.Result);
        var presupuestos = Assert.IsAssignableFrom<IEnumerable<Presupuesto>>(ok.Value).ToList();
        Assert.Equal(totalEnBd, presupuestos.Count);
    }

    [Fact]
    public async Task GetPresupuestos_FiltroSoloMes_SinAnioSeIgnoraYDevuelveTodos()
    {
        using var db = CreateDbContext();
        db.Presupuestos.AddRange(
            CrearPresupuesto(100m, new DateTime(2026, 9, 1), idCategoria: 1),
            CrearPresupuesto(300m, new DateTime(2025, 10, 1), idCategoria: 2));
        await db.SaveChangesAsync();
        var controller = CrearControllerPresupuestos(db);
        int totalEnBd = await db.Presupuestos.CountAsync();

        var result = await controller.GetPresupuestos(null, 9);

        var ok = Assert.IsType<OkObjectResult>(result.Result);
        var presupuestos = Assert.IsAssignableFrom<IEnumerable<Presupuesto>>(ok.Value).ToList();
        Assert.Equal(totalEnBd, presupuestos.Count);
    }

    [Fact]
    public async Task GetPresupuestos_FiltroSinCoincidencias_DevuelveVacio()
    {
        using var db = CreateDbContext();
        db.Presupuestos.Add(CrearPresupuesto(100m, new DateTime(2026, 9, 1), idCategoria: 1));
        await db.SaveChangesAsync();
        var controller = CrearControllerPresupuestos(db);

        var result = await controller.GetPresupuestos(2027, 1);

        var ok = Assert.IsType<OkObjectResult>(result.Result);
        var presupuestos = Assert.IsAssignableFrom<IEnumerable<Presupuesto>>(ok.Value).ToList();
        Assert.Empty(presupuestos);
    }

    [Fact]
    public async Task GetPresupuestos_CincuentaRegistros_SinPaginacionDevuelveTodos()
    {
        using var db = CreateDbContext();
        var presupuestos = Enumerable.Range(1, 50)
            .Select(i => CrearPresupuesto(i * 10m, new DateTime(2026, 1, 1).AddMonths(i % 12), idCategoria: 1));
        db.Presupuestos.AddRange(presupuestos);
        await db.SaveChangesAsync();
        var controller = CrearControllerPresupuestos(db);

        var result = await controller.GetPresupuestos(null, null);

        var ok = Assert.IsType<OkObjectResult>(result.Result);
        var lista = Assert.IsAssignableFrom<IEnumerable<Presupuesto>>(ok.Value).ToList();
        Assert.Equal(50, lista.Count);
        var meses = lista.Select(p => p.MesAnio).ToList();
        for (int i = 0; i < meses.Count - 1; i++)
            Assert.True(meses[i] >= meses[i + 1], "Se esperaba orden por MesAnio descendente");
    }
}