using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RemesaSmartSV.Controllers;
using RemesaSmartSV.Data;
using RemesaSmartSV.Entities;

namespace backend.Tests;

public class CategoriasControllerTests
{
    private const int IdHogar = 42;

    private static ApplicationDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new ApplicationDbContext(options);
    }

    private static CategoriasController CreateController(ApplicationDbContext db)
    {
        var controller = new CategoriasController(db)
        {
            ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext
                {
                    User = new ClaimsPrincipal(new ClaimsIdentity(new[]
                    {
                        new Claim("idHogar", IdHogar.ToString())
                    }, "Test"))
                }
            }
        };
        return controller;
    }

    private static Categoria CrearCategoria(string nombre, string tipo = "Gasto", int idHogar = IdHogar)
        => new() { IdHogar = idHogar, Nombre = nombre, Tipo = tipo };

    [Fact]
    public async Task GetCategorias_SoloDevuelveCategoriasDelHogarOrdenadasPorNombre()
    {
        using var db = CreateDbContext();
        db.Categorias.AddRange(
            CrearCategoria("Zapato", idHogar: IdHogar),
            CrearCategoria("Alimentación", idHogar: IdHogar),
            CrearCategoria("Ajeno", idHogar: IdHogar + 1));
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.GetCategorias();

        var ok = Assert.IsType<OkObjectResult>(result.Result);
        var categorias = Assert.IsAssignableFrom<IEnumerable<Categoria>>(ok.Value).ToList();
        Assert.Equal(2, categorias.Count);
        Assert.Equal(new[] { "Alimentación", "Zapato" }, categorias.Select(c => c.Nombre).ToArray());
        Assert.All(categorias, c => Assert.Equal(IdHogar, c.IdHogar));
    }

    [Fact]
    public async Task GetCategoria_DeMismoHogar_DevuelveCategoria()
    {
        using var db = CreateDbContext();
        var categoria = CrearCategoria("Transporte");
        db.Categorias.Add(categoria);
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.GetCategoria(categoria.IdCategoria);

        var ok = Assert.IsType<OkObjectResult>(result.Result);
        Assert.Same(categoria, ok.Value);
    }

    [Fact]
    public async Task GetCategoria_DeOtroHogar_DevuelveNotFound()
    {
        using var db = CreateDbContext();
        var categoria = CrearCategoria("Ajeno", idHogar: IdHogar + 1);
        db.Categorias.Add(categoria);
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.GetCategoria(categoria.IdCategoria);

        Assert.IsType<NotFoundResult>(result.Result);
    }

    [Fact]
    public async Task GetCategoria_Inexistente_DevuelveNotFound()
    {
        using var db = CreateDbContext();
        var controller = CreateController(db);

        var result = await controller.GetCategoria(999);

        Assert.IsType<NotFoundResult>(result.Result);
    }

    [Fact]
    public async Task Create_AsignaHogarDelUsuarioYPersiste()
    {
        using var db = CreateDbContext();
        var controller = CreateController(db);

        var result = await controller.Create(CrearCategoria("Ahorro", tipo: "Ingreso"));

        var created = Assert.IsType<CreatedAtActionResult>(result.Result);
        var categoria = Assert.IsType<Categoria>(created.Value);
        Assert.Equal(IdHogar, categoria.IdHogar);
        Assert.Equal("Ahorro", categoria.Nombre);
        Assert.Same(categoria, await db.Categorias.SingleAsync());
    }

    [Fact]
    public async Task Create_IgnoraIdCategoriaProporcionado()
    {
        using var db = CreateDbContext();
        db.Categorias.Add(CrearCategoria("Existente"));
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var resultado = await controller.Create(CrearCategoria("Nueva"));

        var created = Assert.IsType<CreatedAtActionResult>(resultado.Result);
        var persistida = Assert.IsType<Categoria>(created.Value);
        Assert.NotEqual(0, persistida.IdCategoria);
        Assert.Equal(IdHogar, persistida.IdHogar);
        Assert.Equal(2, await db.Categorias.CountAsync());
    }

    [Fact]
    public async Task Update_DeMismoHogar_ActualizaCamposYDevuelveNoContent()
    {
        using var db = CreateDbContext();
        var categoria = CrearCategoria("Antiguo", tipo: "Gasto", idHogar: IdHogar);
        db.Categorias.Add(categoria);
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.Update(categoria.IdCategoria, new Categoria
        {
            Nombre = "NuevoNombre",
            Tipo = "Ingreso",
            Icono = "nuevo icono"
        });

        Assert.IsType<NoContentResult>(result);

        var actualizada = await db.Categorias.SingleAsync();
        Assert.Equal("NuevoNombre", actualizada.Nombre);
        Assert.Equal("Ingreso", actualizada.Tipo);
        Assert.Equal("nuevo icono", actualizada.Icono);
        Assert.Equal(IdHogar, actualizada.IdHogar);
    }

    [Fact]
    public async Task Update_DeOtroHogar_NoModificaYDevuelveNotFound()
    {
        using var db = CreateDbContext();
        var categoria = CrearCategoria("Ajeno", idHogar: IdHogar + 1);
        db.Categorias.Add(categoria);
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.Update(categoria.IdCategoria, new Categoria
        {
            Nombre = "Intruso",
            Tipo = "Gasto"
        });

        Assert.IsType<NotFoundResult>(result);

        var enBase = await db.Categorias.SingleAsync();
        Assert.Equal("Ajeno", enBase.Nombre);
    }

    [Fact]
    public async Task Update_Inexistente_DevuelveNotFound()
    {
        using var db = CreateDbContext();
        var controller = CreateController(db);

        var result = await controller.Update(999, new Categoria { Nombre = "Nada", Tipo = "Gasto" });

        Assert.IsType<NotFoundResult>(result);
    }

    [Fact]
    public async Task Delete_DeMismoHogar_EliminaYDevuelveNoContent()
    {
        using var db = CreateDbContext();
        var categoria = CrearCategoria("Temporal", idHogar: IdHogar);
        db.Categorias.Add(categoria);
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.Delete(categoria.IdCategoria);

        Assert.IsType<NoContentResult>(result);
        Assert.Equal(0, await db.Categorias.CountAsync());
    }

    [Fact]
    public async Task Delete_DeOtroHogar_NoEliminaYDevuelveNotFound()
    {
        using var db = CreateDbContext();
        var categoria = CrearCategoria("Ajeno", idHogar: IdHogar + 1);
        db.Categorias.Add(categoria);
        await db.SaveChangesAsync();
        var controller = CreateController(db);

        var result = await controller.Delete(categoria.IdCategoria);

        Assert.IsType<NotFoundResult>(result);
        Assert.Equal(1, await db.Categorias.CountAsync());
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