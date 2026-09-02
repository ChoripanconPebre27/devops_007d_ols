package cl.artelab_spa.artelab.controller;

import java.net.URI;
import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
// import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;
import jakarta.validation.Valid;

import cl.artelab_spa.artelab.model.Producto;
import cl.artelab_spa.artelab.service.ProductoService;


@RestController
@RequestMapping("/api/v1/productos")
// @CrossOrigin(origins ="*")
public class ProductoController {

    @Autowired
    private ProductoService productoService;


    @GetMapping
    public ResponseEntity<List<Producto>> listarProductos() {
        List<Producto> productos = productoService.getAll();
        if (productos.isEmpty()) {
            return ResponseEntity.noContent().build();
        }
        return ResponseEntity.ok(productos);
    }


    @PostMapping
    public ResponseEntity<Producto> agregarProducto(@Valid @RequestBody Producto producto) {
        Producto saved = productoService.save(producto);
        URI location = ServletUriComponentsBuilder.fromCurrentRequest()
                .path("/{id}")
                .buildAndExpand(saved.getId())
                .toUri();
        return ResponseEntity.created(location).body(saved);
    }


    @GetMapping("{id}")
    public ResponseEntity<Producto> buscarProducto(@PathVariable Long id) {
        if (productoService.existsById(id)) {
            return ResponseEntity.status(200).body(productoService.getById(id));
        }
        return ResponseEntity.status(404).build();
    }


    @PutMapping("{id}")
    public ResponseEntity<?> actualizarProducto(@PathVariable Long id, @Valid @RequestBody Producto nuevo) {
        if (productoService.existsById(id)) {
            return ResponseEntity.status(200).body(productoService.update(id, nuevo));
        }
        return ResponseEntity.status(404).build();
    }

    
    @DeleteMapping("{id}")
    public ResponseEntity<Void> eliminarProducto(@PathVariable Long id) {
        if (productoService.existsById(id)) {
            productoService.delete(id);
            return ResponseEntity.noContent().build();
        }
        return ResponseEntity.notFound().build();
    }

}
