package cl.artelab_spa.artelab.model;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.OneToMany;
import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;


@Entity
@Data
@AllArgsConstructor
@NoArgsConstructor
public class Categoria {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(columnDefinition = "INTEGER")
    private Long id; // ID de categoría. Ej: "1"

    
    @Column(length = 30, nullable = false)
    @NotBlank(message = "La descripción de la categoría no puede estar vacía")
    private String des; // Nombre de categoría. Ej: "Lápices"

    @JsonIgnore
    @OneToMany(mappedBy = "categoria", cascade = CascadeType.ALL)
    private List<Producto> productos;

    @JsonIgnore
    @OneToMany(mappedBy = "categoria", cascade = CascadeType.ALL)
    private List<Promocion> promociones;

}
