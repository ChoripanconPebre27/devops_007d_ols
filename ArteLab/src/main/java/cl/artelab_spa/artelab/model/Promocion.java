package cl.artelab_spa.artelab.model;

import java.time.LocalDate;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;


@Entity
@Data
@AllArgsConstructor
@NoArgsConstructor
public class Promocion {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(columnDefinition = "INTEGER")
    private Long id; // ID de promoción. Ej: "1"


    @Column(length = 30, nullable = false)
    @NotBlank(message = "La descripción de la promoción no puede estar vacía")
    private String des; // Nombre de promoción. Ej: "Pinceles 20% Abril"


    @Column(nullable = false)
    private LocalDate fechaIni; // Fecha inicio en formato yyyy-mm-dd. Ej: "2026-04-01"


    @Column(nullable = false)
    private LocalDate fechaTer; // Fecha término en formato yyyy-mm-dd. Ej: "2026-04-30"


    @Column(nullable = false)
    @NotNull(message = "El descuento es obligatorio")
    @Positive(message = "El descuento debe ser un valor positivo")
    @Max(value = 100, message = "El descuento no puede exceder 100")
    private Integer descuento; // Porcentaje de descuento. Ej: "20"

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "idCategoria", nullable = false, columnDefinition = "INTEGER")
    private Categoria categoria;

}
