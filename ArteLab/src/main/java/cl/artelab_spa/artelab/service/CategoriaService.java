package cl.artelab_spa.artelab.service;

import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import cl.artelab_spa.artelab.exception.BusinessRuleViolationException;
import cl.artelab_spa.artelab.model.Categoria;
import cl.artelab_spa.artelab.repository.CategoriaRepository;
import jakarta.persistence.EntityNotFoundException;
import jakarta.transaction.Transactional;


@Service
@Transactional
public class CategoriaService {

    private static final Logger log = LoggerFactory.getLogger(CategoriaService.class);

    @Autowired
    private CategoriaRepository categoriaRepository;


    public List<Categoria> getAll() {
        List<Categoria> categorias = categoriaRepository.findAll();
        log.info("Retrieved categorias, count={}", categorias.size());
        return categorias;
    }


    public Categoria save(Categoria categoria) {
        validateUniqueDescription(categoria.getDes());
        Categoria saved = categoriaRepository.save(categoria);
        log.info("Created categoria id={} des={}", saved.getId(), saved.getDes());
        return saved;
    }


    public Categoria getById(Long id) {
        log.info("Looking up categoria by id={}", id);
        Categoria categoria = categoriaRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Categoría no encontrada"));
        log.info("Found categoria id={}", id);
        return categoria;
    }


    public Categoria update(Long id, Categoria nuevo) {
        Categoria categoria = categoriaRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Categoría no encontrada"));
        if (!categoria.getDes().equals(nuevo.getDes())) {
            validateUniqueDescriptionExcludingId(nuevo.getDes(), id);
        }
        categoria.setDes(nuevo.getDes());
        Categoria updated = categoriaRepository.save(categoria);
        log.info("Updated categoria id={} des={}", updated.getId(), updated.getDes());
        return updated;
    }


    public String delete(Long id) {
        categoriaRepository.deleteById(id);
        log.info("Deleted categoria id={}", id);
        return "categoria eliminada";
    }

    
    public Boolean existsById(Long id) {
        return categoriaRepository.existsById(id);
    }

    private void validateUniqueDescription(String des) {
        if (categoriaRepository.existsByDes(des)) {
            log.warn("Categoria description uniqueness violation: {}", des);
            throw new BusinessRuleViolationException("La descripción de categoría ya existe.");
        }
    }

    private void validateUniqueDescriptionExcludingId(String des, Long id) {
        if (categoriaRepository.existsByDesAndIdNot(des, id)) {
            log.warn("Categoria description uniqueness violation on update: {} id={}", des, id);
            throw new BusinessRuleViolationException("La descripción de categoría ya existe para otro registro.");
        }
    }
}

