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

import cl.artelab_spa.artelab.model.Categoria;
import cl.artelab_spa.artelab.service.CategoriaService;


@RestController
@RequestMapping("/api/v1/categorias")
// @CrossOrigin(origins = "*")
public class CategoriaController {

    @Autowired
    private CategoriaService categoriaService;


    @GetMapping
    public ResponseEntity<List<Categoria>> listarCategorias() {
        List<Categoria> categorias = categoriaService.getAll();
        if (categorias.isEmpty()) {
            return ResponseEntity.noContent().build();
        }
        return ResponseEntity.ok(categorias);
    }


    @PostMapping
    public ResponseEntity<Categoria> agregarCategoria(@Valid @RequestBody Categoria categoria) {
        Categoria saved = categoriaService.save(categoria);
        URI location = ServletUriComponentsBuilder.fromCurrentRequest()
                .path("/{id}")
                .buildAndExpand(saved.getId())
                .toUri();
        return ResponseEntity.created(location).body(saved);
    }


    @GetMapping("{id}")
    public ResponseEntity<Categoria> buscarCategoria(@PathVariable Long id) {
        if (categoriaService.existsById(id)) {
            return ResponseEntity.status(200).body(categoriaService.getById(id));
        }
        return ResponseEntity.status(404).build();
    }


    @PutMapping("{id}")
    public ResponseEntity<?> actualizarCategoria(@PathVariable Long id, @Valid @RequestBody Categoria nuevo) {
        if (categoriaService.existsById(id)) {
            return ResponseEntity.status(200).body(categoriaService.update(id, nuevo));
        }
        return ResponseEntity.status(404).build();
    }

    
    @DeleteMapping("{id}")
    public ResponseEntity<Void> eliminarCategoria(@PathVariable Long id) {
        if (categoriaService.existsById(id)) {
            categoriaService.delete(id);
            return ResponseEntity.noContent().build();
        }
        return ResponseEntity.notFound().build();
    }

}
