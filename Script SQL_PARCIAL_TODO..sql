-- CONSULTA--
USE db_reservas_eventos;

-- 1. Salones libres durante todo el dia 15/11/2025.
-- Excluye reservas activas que se crucen con cualquier parte de ese dia.
SELECT s.nombre, s.capacidad, s.precio_hora AS tarifa_por_hora
FROM salones AS s
WHERE s.estado <> 'En mantenimiento'
  AND s.id NOT IN (
      SELECT r.salon_id
      FROM reservas AS r
      WHERE r.estado_reserva <> 'Cancelada'
        AND r.fecha_inicio < '2025-11-16 00:00:00'
        AND r.fecha_fin > '2025-11-15 00:00:00'
  )
ORDER BY s.nombre;

-- 2. Capacidad entre 50 y 150 personas y tarifa menor a $500.000.
SELECT nombre, capacidad, precio_hora AS tarifa_por_hora
FROM salones
WHERE capacidad BETWEEN 50 AND 150
  AND precio_hora < 500000
ORDER BY precio_hora ASC;

-- VISTA_SALONES_DISPONIBLES --

DROP VIEW IF EXISTS vista_salones_disponibles;
CREATE VIEW vista_salones_disponibles AS
SELECT
    s.id AS salon_id,
    s.nombre,
    s.capacidad,
    s.ubicacion,
    s.precio_hora AS tarifa_por_hora,
    CASE
        WHEN s.estado = 'En mantenimiento' THEN 'En mantenimiento'
        WHEN EXISTS (
            SELECT 1
            FROM reservas r
            WHERE r.salon_id = s.id
              AND r.estado_reserva <> 'Cancelada'
              AND NOW() >= r.fecha_inicio
              AND NOW() < r.fecha_fin
        ) THEN 'Ocupado'
        ELSE 'Disponible'
    END AS estado_actual
FROM salones s;

-- Comprobacion:
-- SELECT * FROM vista_salones_disponibles ORDER BY nombre;


-- FUNCION_CALCULAR_TARIFA--

DROP FUNCTION IF EXISTS calcular_tarifa_total;
DELIMITER $$
CREATE FUNCTION calcular_tarifa_total(
    p_tarifa_base DECIMAL(10,2),
    p_horas DECIMAL(8,2)
)
RETURNS DECIMAL(12,2)
DETERMINISTIC
NO SQL
BEGIN
    IF p_tarifa_base IS NULL OR p_horas IS NULL
       OR p_tarifa_base < 0 OR p_horas <= 0 THEN
        RETURN NULL;
    END IF;

    RETURN ROUND(p_tarifa_base * p_horas * 1.10, 2);
END$$
DELIMITER ;

-- Resultado esperado: 396000.00
SELECT calcular_tarifa_total(120000, 3) AS total_con_mantenimiento;

-- TRIGGER 5:ACTUALIZAR_ESTADO_SALON.----

-- Validacion y actualizacion del estado de salones.
USE db_reservas_eventos;

-- Permitir los tres estados que usa el modulo.
ALTER TABLE salones
MODIFY estado ENUM('Disponible', 'Ocupado', 'En mantenimiento')
NOT NULL DEFAULT 'Disponible';

DELIMITER $$

DROP TRIGGER IF EXISTS validar_reserva_trigger$$
CREATE TRIGGER validar_reserva_trigger
BEFORE INSERT ON reservas
FOR EACH ROW
BEGIN
    DECLARE v_estado VARCHAR(30);
    DECLARE v_cruces INT DEFAULT 0;

    IF NEW.fecha_inicio IS NULL OR NEW.fecha_fin IS NULL
       OR NEW.fecha_fin <= NEW.fecha_inicio THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La fecha final debe ser posterior a la inicial';
    END IF;

    IF NEW.total_horas IS NULL OR NEW.total_horas <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El total de horas debe ser mayor que cero';
    END IF;

    SELECT MAX(estado) INTO v_estado
    FROM salones WHERE id = NEW.salon_id;

    IF v_estado IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El salon indicado no existe';
    END IF;

    IF v_estado = 'En mantenimiento' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El salon esta en mantenimiento';
    END IF;

    IF NEW.estado_reserva <> 'Cancelada' THEN
        SELECT COUNT(*) INTO v_cruces
        FROM reservas
        WHERE salon_id = NEW.salon_id
          AND estado_reserva <> 'Cancelada'
          AND fecha_inicio < NEW.fecha_fin
          AND fecha_fin > NEW.fecha_inicio;

        IF v_cruces > 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El salon ya tiene una reserva en ese horario';
        END IF;
    END IF;
END$$

DROP TRIGGER IF EXISTS actualizar_estado_salon$$
CREATE TRIGGER actualizar_estado_salon
AFTER INSERT ON reservas
FOR EACH ROW
BEGIN
    IF NEW.estado_reserva <> 'Cancelada' THEN
        UPDATE salones
        SET estado = 'Ocupado'
        WHERE id = NEW.salon_id
          AND estado <> 'En mantenimiento';
    END IF;
END$$

DROP TRIGGER IF EXISTS liberar_salon$$
CREATE TRIGGER liberar_salon
AFTER DELETE ON reservas
FOR EACH ROW
BEGIN
    DECLARE v_reservas INT DEFAULT 0;

    SELECT COUNT(*) INTO v_reservas
    FROM reservas
    WHERE salon_id = OLD.salon_id
      AND estado_reserva <> 'Cancelada';

    IF v_reservas = 0 THEN
        UPDATE salones
        SET estado = 'Disponible'
        WHERE id = OLD.salon_id
          AND estado = 'Ocupado';
    END IF;
END$$

-- Mantiene el estado sincronizado si una reserva se cancela o reactiva.
DROP TRIGGER IF EXISTS sincronizar_estado_reserva_update$$
CREATE TRIGGER sincronizar_estado_reserva_update
AFTER UPDATE ON reservas
FOR EACH ROW
BEGIN
    DECLARE v_activas INT DEFAULT 0;

    IF OLD.salon_id <> NEW.salon_id THEN
        SELECT COUNT(*) INTO v_activas
        FROM reservas
        WHERE salon_id = OLD.salon_id
          AND estado_reserva <> 'Cancelada';
        IF v_activas = 0 THEN
            UPDATE salones SET estado = 'Disponible'
            WHERE id = OLD.salon_id AND estado = 'Ocupado';
        END IF;
    END IF;

    SELECT COUNT(*) INTO v_activas
    FROM reservas
    WHERE salon_id = NEW.salon_id
      AND estado_reserva <> 'Cancelada';

    IF v_activas > 0 THEN
        UPDATE salones SET estado = 'Ocupado'
        WHERE id = NEW.salon_id AND estado <> 'En mantenimiento';
    ELSE
        UPDATE salones SET estado = 'Disponible'
        WHERE id = NEW.salon_id AND estado = 'Ocupado';
    END IF;
END$$

DROP TRIGGER IF EXISTS auditoria_precios_trigger$$
CREATE TRIGGER auditoria_precios_trigger
AFTER UPDATE ON salones
FOR EACH ROW
BEGIN
    IF OLD.precio_hora <> NEW.precio_hora THEN
        INSERT INTO auditoria_precios
            (salon_id, usuario, precio_anterior, precio_nuevo)
        VALUES
            (OLD.id, CURRENT_USER(), OLD.precio_hora, NEW.precio_hora);
    END IF;
END$$

DELIMITER ;

-- Ver triggers instalados:
SHOW TRIGGERS;

