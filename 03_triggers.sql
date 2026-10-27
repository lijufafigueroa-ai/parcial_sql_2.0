-- ============================================================================
-- 03_triggers.sql: TRIGGERS DE CONTROL Y AUDITORÍA
-- ============================================================================

USE db_reservas_eventos;

DELIMITER $$

-- Trigger 1: Validar reserva antes de insertar (cruces y mantenimiento)
DROP TRIGGER IF EXISTS validar_reserva_trigger$$
CREATE TRIGGER validar_reserva_trigger
BEFORE INSERT ON reservas
FOR EACH ROW
BEGIN
    DECLARE v_estado VARCHAR(30);
    DECLARE v_cruces INT DEFAULT 0;

    IF NEW.fecha_fin <= NEW.fecha_inicio THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La fecha final debe ser posterior a la inicial';
    END IF;

    SET v_estado = (SELECT estado FROM salones WHERE id = NEW.salon_id);
    IF v_estado = 'En mantenimiento' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El salon esta en mantenimiento';
    END IF;

    SELECT COUNT(*) INTO v_cruces FROM reservas
    WHERE salon_id = NEW.salon_id AND estado_reserva <> 'Cancelada'
      AND fecha_inicio < NEW.fecha_fin AND fecha_fin > NEW.fecha_inicio;

    IF v_cruces > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El salon ya tiene una reserva en ese horario';
    END IF;
END$$

-- Trigger 2: Marcar salón como Ocupado al reservar
DROP TRIGGER IF EXISTS actualizar_estado_salon$$
CREATE TRIGGER actualizar_estado_salon
AFTER INSERT ON reservas
FOR EACH ROW
BEGIN
    IF NEW.estado_reserva <> 'Cancelada' THEN
        UPDATE salones SET estado = 'Ocupado' WHERE id = NEW.salon_id;
    END IF;
END$$

-- Trigger 3: Liberar el salón al eliminar una reserva
DROP TRIGGER IF EXISTS liberar_salon$$
CREATE TRIGGER liberar_salon
AFTER DELETE ON reservas
FOR EACH ROW
BEGIN
    DECLARE v_reservas INT DEFAULT 0;
    SELECT COUNT(*) INTO v_reservas FROM reservas WHERE salon_id = OLD.salon_id AND estado_reserva <> 'Cancelada';
    IF v_reservas = 0 THEN
        UPDATE salones SET estado = 'Disponible' WHERE id = OLD.salon_id AND estado = 'Ocupado';
    END IF;
END$$

-- Trigger 4: Auditoría de cambios de precio por hora
DROP TRIGGER IF EXISTS auditoria_precios_trigger$$
CREATE TRIGGER auditoria_precios_trigger
AFTER UPDATE ON salones
FOR EACH ROW
BEGIN
    IF OLD.precio_hora <> NEW.precio_hora THEN
        INSERT INTO auditoria_precios (salon_id, usuario, precio_anterior, precio_nuevo)
        VALUES (OLD.id, CURRENT_USER(), OLD.precio_hora, NEW.precio_hora);
    END IF;
END$$

DELIMITER ;