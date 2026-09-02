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

import cl.artelab_spa.artelab.model.Promocion;
import cl.artelab_spa.artelab.service.PromocionService;


@RestController
@RequestMapping("/api/v1/promociones")
// @CrossOrigin(origins = "*")
public class PromocionController {

    @Autowired
    private PromocionService promocionService;

    
    @GetMapping
    public ResponseEntity<List<Promocion>> listarPromociones() {
        List<Promocion> promociones = promocionService.getAll();
        if (promociones.isEmpty()) {
            return ResponseEntity.noContent().build();
        }
        return ResponseEntity.ok(promociones);
    }


    @PostMapping
    public ResponseEntity<Promocion> agregarPromocion(@Valid @RequestBody Promocion promocion) {
        Promocion saved = promocionService.save(promocion);
        URI location = ServletUriComponentsBuilder.fromCurrentRequest()
                .path("/{id}")
                .buildAndExpand(saved.getId())
                .toUri();
        return ResponseEntity.created(location).body(saved);
    }

    @PostMapping("/usuario/{usuarioId}")
    public ResponseEntity<Promocion> agregarPromocionParaUsuario(@PathVariable Long usuarioId, @Valid @RequestBody Promocion promocion) {
        Promocion saved = promocionService.saveForUsuario(usuarioId, promocion);
        URI location = ServletUriComponentsBuilder.fromCurrentRequest()
                .path("/{id}")
                .buildAndExpand(saved.getId())
                .toUri();
        return ResponseEntity.created(location).body(saved);
    }


    @GetMapping("{id}")
    public ResponseEntity<Promocion> buscarPromocion(@PathVariable Long id) {
        if (promocionService.existsById(id)) {
            return ResponseEntity.status(200).body(promocionService.getById(id));
        }
        return ResponseEntity.status(404).build();
    }


    @PutMapping("{id}")
    public ResponseEntity<?> actualizarPromocion(@PathVariable Long id, @Valid @RequestBody Promocion nuevo) {
        if (promocionService.existsById(id)) {
            return ResponseEntity.status(200).body(promocionService.update(id, nuevo));
        }
        return ResponseEntity.status(404).build();
    }


    @DeleteMapping("{id}")
    public ResponseEntity<Void> eliminarPromocion(@PathVariable Long id) {
        if (promocionService.existsById(id)) {
            promocionService.delete(id);
            return ResponseEntity.noContent().build();
        }
        return ResponseEntity.notFound().build();
    }

}
