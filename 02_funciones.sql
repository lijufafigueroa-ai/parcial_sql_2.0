-- ============================================================================
-- 02_functions.sql: FUNCIONES PERSONALIZADAS
-- ============================================================================

USE db_reservas_eventos;

DELIMITER $$

-- Función 1: Calcular total con IVA del 19%
DROP FUNCTION IF EXISTS calcular_total_reserva$$
CREATE FUNCTION calcular_total_reserva(
    p_precio_hora DECIMAL(10,2),
    p_horas DECIMAL(8,2)
)
RETURNS DECIMAL(12,2)
DETERMINISTIC
NO SQL
BEGIN
    IF p_precio_hora IS NULL OR p_horas IS NULL OR p_precio_hora < 0 OR p_horas <= 0 THEN
        RETURN NULL;
    END IF;
    RETURN ROUND(p_precio_hora * p_horas * 1.19, 2);
END$$

-- Función 2: Verificar disponibilidad de horarios

DROP FUNCTION IF EXISTS verificar_disponibilidad$$
CREATE FUNCTION verificar_disponibilidad(
    p_salon_id INT,
    p_fecha_inicio DATETIME,
    p_fecha_fin DATETIME
)
RETURNS TINYINT
READS SQL DATA
BEGIN
    DECLARE v_estado VARCHAR(30);
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_cruces INT DEFAULT 0;

    IF p_salon_id IS NULL OR p_fecha_inicio IS NULL OR p_fecha_fin IS NULL OR p_fecha_fin <= p_fecha_inicio THEN
        RETURN 0;
    END IF;

    SELECT COUNT(*), MAX(estado) INTO v_existe, v_estado FROM salones WHERE id = p_salon_id;
    IF v_existe = 0 OR v_estado = 'En mantenimiento' THEN RETURN 0; END IF;

    SELECT COUNT(*) INTO v_cruces FROM reservas
    WHERE salon_id = p_salon_id AND estado_reserva <> 'Cancelada'
      AND fecha_inicio < p_fecha_fin AND fecha_fin > p_fecha_inicio;

    IF v_cruces = 0 THEN RETURN 1; ELSE RETURN 0; END IF;
END$$

DELIMITER ;