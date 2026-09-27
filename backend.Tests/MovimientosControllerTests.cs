using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RemesaSmartSV.Controllers;
using RemesaSmartSV.Data;
using RemesaSmartSV.Entities;

namespace backend.Tests;

public class MovimientosControllerTests
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

    private static MovimientosController CreateController(ApplicationDbContext db)
    {
        var controller = new MovimientosController(db)
        {
            ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext
                {
                    User = new ClaimsPrincipal(new ClaimsIdentity(new[]
                    {
                        new Claim("idHogar", IdHogar.ToString()),
                        new Claim("idUsuario", IdUsuario.ToString())
                    }, "Test"))
                }
            }
        };
        return controller;
    }

    private static Categoria CrearCategoria(string nombre, string tipo = "Gasto", int idHogar = IdHogar)
        => new() { IdHogar = idHogar, Nombre = nombre, Tipo = tipo };

    private static Movimiento CrearMovimiento(decimal monto, DateTime fecha, string tipo, int idCategoria, int idHogar = IdHogar, int idUsuario = IdUsuario)
        => new() { IdHogar = idHogar, IdUsuario = idUsuario, IdCategoria = idCategoria, Monto = monto, Fecha = fecha, Tipo = tipo };

    [Fact]
    public async Task GetMovimientos_SinFiltros_DevuelveDelHogarOrdenadosPorFechaDescendente()
    {
        using var db = CreateDbContext();
        db.Movimientos.AddRange(
            CrearMovimiento(100m, new DateTime(2026, 1, 3), "Gasto", idCategoria: 1),
            CrearMovimiento(50m, new DateTime(2026, 1, 1), "Ingreso", idCategoria: 1),
            CrearMovimiento(75m, new DateTime(2026, 1, 2), "Gasto", idCategoria: 2),
            CrearMovimiento(999m, new DateTime(2025, 12, 31), "Gasto", idCategoria: 1, idHogar: IdHogar + 1));
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.GetMovimientos(null, null);

        var ok = Assert.IsType<OkObjectResult>(result.Result);
        var movimientos = Assert.IsAssignableFrom<IEnumerable<Movimiento>>(ok.Value).ToList();
        Assert.Equal(3, movimientos.Count);
        Assert.Equal(new[] { 100m, 75m, 50m }, movimientos.Select(m => m.Monto).ToArray());
        Assert.All(movimientos, m => Assert.Equal(IdHogar, m.IdHogar));
    }

    [Fact]
    public async Task GetMovimientos_ConFiltroCategoriaId_SoloDevuelveDeEsaCategoria()
    {
        using var db = CreateDbContext();
        db.Movimientos.AddRange(
            CrearMovimiento(100m, new DateTime(2026, 1, 3), "Gasto", idCategoria: 1),
            CrearMovimiento(50m, new DateTime(2026, 1, 1), "Ingreso", idCategoria: 1),
            CrearMovimiento(75m, new DateTime(2026, 1, 2), "Gasto", idCategoria: 2));
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.GetMovimientos(1, null);

        var ok = Assert.IsType<OkObjectResult>(result.Result);
        var movimientos = Assert.IsAssignableFrom<IEnumerable<Movimiento>>(ok.Value).ToList();
        Assert.Equal(2, movimientos.Count);
        Assert.All(movimientos, m => Assert.Equal(1, m.IdCategoria));
        Assert.Equal(new[] { 100m, 50m }, movimientos.Select(m => m.Monto).ToArray());
    }

    [Fact]
    public async Task GetMovimientos_ConFiltroTipo_SoloDevuelveDeEseTipo()
    {
        using var db = CreateDbContext();
        db.Movimientos.AddRange(
            CrearMovimiento(100m, new DateTime(2026, 1, 3), "Gasto", idCategoria: 1),
            CrearMovimiento(50m, new DateTime(2026, 1, 1), "Ingreso", idCategoria: 1),
            CrearMovimiento(75m, new DateTime(2026, 1, 2), "Gasto", idCategoria: 2));
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.GetMovimientos(null, "Gasto");

        var ok = Assert.IsType<OkObjectResult>(result.Result);
        var movimientos = Assert.IsAssignableFrom<IEnumerable<Movimiento>>(ok.Value).ToList();
        Assert.Equal(2, movimientos.Count);
        Assert.All(movimientos, m => Assert.Equal("Gasto", m.Tipo));
    }

    [Fact]
    public async Task GetMovimientos_ConFiltroTipoEnMinusculas_DevuelveVacio()
    {
        using var db = CreateDbContext();
        db.Movimientos.Add(CrearMovimiento(100m, new DateTime(2026, 1, 3), "Gasto", idCategoria: 1));
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.GetMovimientos(null, "gasto");

        var ok = Assert.IsType<OkObjectResult>(result.Result);
        var movimientos = Assert.IsAssignableFrom<IEnumerable<Movimiento>>(ok.Value).ToList();
        Assert.Empty(movimientos);
    }

    [Fact]
    public async Task GetMovimiento_DeMismoHogar_DevuelveMovimiento()
    {
        using var db = CreateDbContext();
        var movimiento = CrearMovimiento(100m, new DateTime(2026, 1, 3), "Gasto", idCategoria: 1);
        db.Movimientos.Add(movimiento);
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.GetMovimiento(movimiento.IdMovimiento);

        var ok = Assert.IsType<OkObjectResult>(result.Result);
        Assert.Same(movimiento, ok.Value);
    }

    [Fact]
    public async Task GetMovimiento_DeOtroHogar_DevuelveNotFound()
    {
        using var db = CreateDbContext();
        var movimiento = CrearMovimiento(100m, new DateTime(2026, 1, 3), "Gasto", idCategoria: 1, idHogar: IdHogar + 1);
        db.Movimientos.Add(movimiento);
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.GetMovimiento(movimiento.IdMovimiento);

        Assert.IsType<NotFoundResult>(result.Result);
    }

    [Fact]
    public async Task GetMovimiento_Inexistente_DevuelveNotFound()
    {
        using var db = CreateDbContext();
        var controller = CreateController(db);

        var result = await controller.GetMovimiento(999);

        Assert.IsType<NotFoundResult>(result.Result);
    }

    [Fact]
    public async Task Create_ConCategoriaDelHogar_AsignaHogarYUsuarioYPersiste()
    {
        using var db = CreateDbContext();
        db.Categorias.Add(CrearCategoria("Transporte"));
        await db.SaveChangesAsync();
        var categoria = await db.Categorias.SingleAsync();
        var controller = CreateController(db);

        var result = await controller.Create(CrearMovimiento(100m, new DateTime(2026, 1, 3), "Gasto", idCategoria: categoria.IdCategoria));

        var created = Assert.IsType<CreatedAtActionResult>(result.Result);
        var movimiento = Assert.IsType<Movimiento>(created.Value);
        Assert.Equal(IdHogar, movimiento.IdHogar);
        Assert.Equal(IdUsuario, movimiento.IdUsuario);
        Assert.Equal(categoria.IdCategoria, movimiento.IdCategoria);
        Assert.Same(movimiento, await db.Movimientos.SingleAsync());
    }

    [Fact]
    public async Task Create_ConCategoriaDeOtroHogar_DevuelveBadRequestYNoPersiste()
    {
        using var db = CreateDbContext();
        db.Categorias.Add(CrearCategoria("Ajeno", idHogar: IdHogar + 1));
        await db.SaveChangesAsync();
        var categoria = await db.Categorias.SingleAsync();
        var controller = CreateController(db);

        var result = await controller.Create(CrearMovimiento(100m, new DateTime(2026, 1, 3), "Gasto", idCategoria: categoria.IdCategoria));

        Assert.IsType<BadRequestObjectResult>(result.Result);
        Assert.Equal(0, await db.Movimientos.CountAsync());
    }

    [Fact]
    public async Task Create_ConCategoriaInexistente_DevuelveBadRequestYNoPersiste()
    {
        using var db = CreateDbContext();
        var controller = CreateController(db);

        var result = await controller.Create(CrearMovimiento(100m, new DateTime(2026, 1, 3), "Gasto", idCategoria: 999));

        Assert.IsType<BadRequestObjectResult>(result.Result);
        Assert.Equal(0, await db.Movimientos.CountAsync());
    }

    [Fact]
    public async Task Update_DeMismoHogar_ActualizaCamposYDevuelveNoContent()
    {
        using var db = CreateDbContext();
        var movimiento = CrearMovimiento(100m, new DateTime(2026, 1, 3), "Gasto", idCategoria: 1);
        db.Movimientos.Add(movimiento);
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.Update(movimiento.IdMovimiento, new Movimiento
        {
            IdCategoria = movimiento.IdCategoria,
            Monto = 250m,
            Fecha = new DateTime(2026, 2, 1),
            Tipo = "Ingreso",
            Descripcion = "Sueldo",
            OrigenEmisora = "Banco X"
        });

        Assert.IsType<NoContentResult>(result);

        var actualizado = await db.Movimientos.SingleAsync();
        Assert.Equal(250m, actualizado.Monto);
        Assert.Equal(new DateTime(2026, 2, 1), actualizado.Fecha);
        Assert.Equal("Ingreso", actualizado.Tipo);
        Assert.Equal("Sueldo", actualizado.Descripcion);
        Assert.Equal("Banco X", actualizado.OrigenEmisora);
        Assert.Equal(IdHogar, actualizado.IdHogar);
        Assert.Equal(IdUsuario, actualizado.IdUsuario);
    }

    [Fact]
    public async Task Update_CambioACategoriaValidaDelHogar_ActualizaIdCategoria()
    {
        using var db = CreateDbContext();
        db.Categorias.AddRange(CrearCategoria("Transporte"), CrearCategoria("Comida"));
        await db.SaveChangesAsync();
        var categorias = await db.Categorias.OrderBy(c => c.IdCategoria).ToListAsync();
        var movimiento = CrearMovimiento(100m, new DateTime(2026, 1, 3), "Gasto", idCategoria: categorias[0].IdCategoria);
        db.Movimientos.Add(movimiento);
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.Update(movimiento.IdMovimiento, new Movimiento
        {
            IdCategoria = categorias[1].IdCategoria,
            Monto = 100m,
            Fecha = movimiento.Fecha,
            Tipo = "Gasto"
        });

        Assert.IsType<NoContentResult>(result);
        Assert.Equal(categorias[1].IdCategoria, (await db.Movimientos.SingleAsync()).IdCategoria);
    }

    [Fact]
    public async Task Update_CambioACategoriaDeOtroHogar_DevuelveBadRequestYNoCambia()
    {
        using var db = CreateDbContext();
        var categoriaAjena = CrearCategoria("Ajeno", idHogar: IdHogar + 1);
        categoriaAjena.IdCategoria = 2;
        db.Categorias.Add(categoriaAjena);
        await db.SaveChangesAsync();
        var movimiento = CrearMovimiento(100m, new DateTime(2026, 1, 3), "Gasto", idCategoria: 1);
        db.Movimientos.Add(movimiento);
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.Update(movimiento.IdMovimiento, new Movimiento
        {
            IdCategoria = categoriaAjena.IdCategoria,
            Monto = 999m,
            Fecha = new DateTime(2026, 5, 5),
            Tipo = "Ingreso"
        });

        Assert.IsType<BadRequestObjectResult>(result);

        var enBase = await db.Movimientos.SingleAsync();
        Assert.Equal(100m, enBase.Monto);
        Assert.Equal("Gasto", enBase.Tipo);
        Assert.Equal(1, enBase.IdCategoria);
    }

    [Fact]
    public async Task Update_DeOtroHogar_DevuelveNotFound()
    {
        using var db = CreateDbContext();
        var movimiento = CrearMovimiento(100m, new DateTime(2026, 1, 3), "Gasto", idCategoria: 1, idHogar: IdHogar + 1);
        db.Movimientos.Add(movimiento);
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.Update(movimiento.IdMovimiento, new Movimiento { Monto = 1m, Fecha = DateTime.UtcNow, Tipo = "Gasto" });

        Assert.IsType<NotFoundResult>(result);
        Assert.Equal(100m, (await db.Movimientos.SingleAsync()).Monto);
    }

    [Fact]
    public async Task Update_Inexistente_DevuelveNotFound()
    {
        using var db = CreateDbContext();
        var controller = CreateController(db);

        var result = await controller.Update(999, new Movimiento { Monto = 1m, Fecha = DateTime.UtcNow, Tipo = "Gasto" });

        Assert.IsType<NotFoundResult>(result);
    }

    [Fact]
    public async Task Delete_DeMismoHogar_EliminaYDevuelveNoContent()
    {
        using var db = CreateDbContext();
        var movimiento = CrearMovimiento(100m, new DateTime(2026, 1, 3), "Gasto", idCategoria: 1);
        db.Movimientos.Add(movimiento);
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.Delete(movimiento.IdMovimiento);

        Assert.IsType<NoContentResult>(result);
        Assert.Equal(0, await db.Movimientos.CountAsync());
    }

    [Fact]
    public async Task Delete_DeOtroHogar_NoEliminaYDevuelveNotFound()
    {
        using var db = CreateDbContext();
        var movimiento = CrearMovimiento(100m, new DateTime(2026, 1, 3), "Gasto", idCategoria: 1, idHogar: IdHogar + 1);
        db.Movimientos.Add(movimiento);
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.Delete(movimiento.IdMovimiento);

        Assert.IsType<NotFoundResult>(result);
        Assert.Equal(1, await db.Movimientos.CountAsync());
    }

    [Fact]
    public async Task Delete_Inexistente_DevuelveNotFound()
    {
        using var db = CreateDbContext();
        var controller = CreateController(db);

        var result = await controller.Delete(999);

        Assert.IsType<NotFoundResult>(result);
    }
}