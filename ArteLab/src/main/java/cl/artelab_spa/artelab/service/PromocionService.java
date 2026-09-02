package cl.artelab_spa.artelab.service;

import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import cl.artelab_spa.artelab.client.UsuarioClient;
import cl.artelab_spa.artelab.dto.UsuarioLookupDto;
import cl.artelab_spa.artelab.exception.BusinessRuleViolationException;
import cl.artelab_spa.artelab.model.Promocion;
import cl.artelab_spa.artelab.repository.PromocionRepository;
import jakarta.persistence.EntityNotFoundException;
import jakarta.transaction.Transactional;


@Service
@Transactional
public class PromocionService {

    private static final Logger log = LoggerFactory.getLogger(PromocionService.class);

    @Autowired
    private PromocionRepository promocionRepository;

    @Autowired
    private UsuarioClient usuarioClient;


    public List<Promocion> getAll() {
        List<Promocion> promociones = promocionRepository.findAll();
        log.info("Retrieved promociones, count={}", promociones.size());
        return promociones;
    }


    public Promocion save(Promocion promocion) {
        validateDiscount(promocion.getDescuento());
        Promocion saved = promocionRepository.save(promocion);
        log.info("Created promocion id={} descuento={}", saved.getId(), saved.getDescuento());
        return saved;
    }

    public Promocion saveForUsuario(Long usuarioId, Promocion promocion) {
        UsuarioLookupDto usuario = usuarioClient.findUsuarioById(usuarioId)
                .orElseThrow(() -> new EntityNotFoundException("Usuario no encontrado"));
        validateDiscount(promocion.getDescuento());
        Promocion saved = promocionRepository.save(promocion);
        log.info("Created promocion id={} for usuario id={} nombreUsuario={}", saved.getId(), usuario.getId(), usuario.getNombreUsuario());
        return saved;
    }


    public Promocion getById(Long id) {
        log.info("Looking up promocion by id={}", id);
        Promocion promocion = promocionRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Promoción no encontrada"));
        log.info("Found promocion id={}", id);
        return promocion;
    }


    public Promocion update(Long id, Promocion nuevo) {
        Promocion promocion = promocionRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Promoción no encontrada"));
        validateDiscount(nuevo.getDescuento());
        promocion.setDes(nuevo.getDes());
        promocion.setDescuento(nuevo.getDescuento());
        promocion.setFechaIni(nuevo.getFechaIni());
        promocion.setFechaTer(nuevo.getFechaTer());
        promocion.setCategoria(nuevo.getCategoria());
        Promocion updated = promocionRepository.save(promocion);
        log.info("Updated promocion id={} descuento={}", updated.getId(), updated.getDescuento());
        return updated;
    }


    public String delete(Long id) {
        promocionRepository.deleteById(id);
        log.info("Deleted promocion id={}", id);
        return "promocion eliminada";
    }


    public Boolean existsById(Long id) {
        return promocionRepository.existsById(id);
    }

    private void validateDiscount(Integer descuento) {
        if (descuento == null || descuento < 0 || descuento > 100) {
            log.warn("Promocion discount business rule violation: {}", descuento);
            throw new BusinessRuleViolationException("El descuento debe estar entre 0 y 100.");
        }
    }
}

