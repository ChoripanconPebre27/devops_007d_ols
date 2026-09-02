package cl.artelab_spa.artelab.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Data
@AllArgsConstructor
@NoArgsConstructor
public class Producto {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(columnDefinition = "INTEGER")
    private Long id; // NÃºmero de 6 digitos del codigo de barra. Es el ID del producto. Ej: "123456"


    @Column(length = 30, nullable = false)
    @NotBlank(message = "La descripciÃ³n del producto no puede estar vacÃ­a")
    private String des; // Nombre. Ej: "Set 12 marcadores color Artel"


    @Column(nullable = false)
    @NotNull(message = "El precio del producto es obligatorio")
    @Positive(message = "El precio debe ser un valor positivo")
    private Integer precio; // Precio. Ej: "8990"


    @Column(nullable = false)
    @NotNull(message = "El stock del producto es obligatorio")
    @PositiveOrZero(message = "El stock debe ser cero o un nÃºmero positivo")
    private Integer stock; // Cantidad de productos a libre disposiciÃ³n. Ej: "7"

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "idCategoria", nullable = false, columnDefinition = "INTEGER")
    private Categoria categoria;

}

