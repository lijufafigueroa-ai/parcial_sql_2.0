-- ============================================================================
-- 04_data_and_queries.sql: DATOS, VISTAS Y CONSULTAS
-- ============================================================================

USE db_reservas_eventos;

-- 1. Inserción de datos base
INSERT INTO salones (nombre, capacidad, precio_hora, estado, encargado) VALUES
('Salon Principal', 100, 120000, 'Disponible', 'Carlos Perez'),
('Salon Ejecutivo', 40, 80000, 'Disponible', 'Laura Gomez'),
('Salon Familiar', 60, 95000, 'Disponible', 'Andres Ruiz'),
('Salon Norte', 30, 70000, 'En mantenimiento', 'Marta Diaz');

INSERT INTO clientes (nombre_completo, identificacion, telefono, correo, tipo_cliente) VALUES
('Juan David Figueroa', 'PRUEBA1001', '3001112233', 'juan.prueba@example.com', 'Individual'),
('Maria Rodriguez', 'PRUEBA1002', '3002223344', 'maria.prueba@example.com', 'Individual'),
('Empresa Eventos SAS', 'PRUEBA1003', '3003334455', 'eventos.prueba@example.com', 'Corporativo');

-- 2. Inserción de reservas de prueba usando la función de IVA
INSERT INTO reservas (salon_id, cliente_id, fecha_inicio, fecha_fin, total_horas, valor_total, estado_reserva) VALUES
(1, 1, '2026-11-10 09:00:00', '2026-11-10 12:00:00', 3, calcular_total_reserva(120000, 3), 'Confirmada'),
(2, 2, '2026-11-11 14:00:00', '2026-11-11 16:00:00', 2, calcular_total_reserva(80000, 2), 'Confirmada'),
(3, 3, '2026-11-12 08:00:00', '2026-11-12 12:00:00', 4, calcular_total_reserva(95000, 4), 'Confirmada'),
(2, 3, '2026-11-15 14:00:00', '2026-11-15 18:00:00', 4, calcular_total_reserva(80000, 4), 'Confirmada'),
(3, 3, '2026-11-20 10:00:00', '2026-11-20 13:00:00', 3, calcular_total_reserva(95000, 3), 'Confirmada'),
(1, 3, '2026-11-25 09:00:00', '2026-11-25 12:00:00', 3, calcular_total_reserva(120000, 3), 'Pendiente');

INSERT INTO pagos (reserva_id, monto_pagado, metodo_pago) VALUES
(1, 428400.00, 'Transferencia'),
(2, 190400.00, 'Tarjeta');

-- 3. Vista requerida
CREATE OR REPLACE VIEW vista_resumen_reservas AS
SELECT 
    c.nombre_completo AS cliente,
    s.nombre AS salon,
    r.fecha_inicio,
    r.fecha_fin,
    r.valor_total AS total,
    r.estado_reserva AS estado
FROM reservas r
INNER JOIN clientes c ON r.cliente_id = c.id
INNER JOIN salones s ON r.salon_id = s.id;

-- 4. Consultas analíticas requeridas
-- Consulta 1: BETWEEN para rango de fechas
SELECT * FROM reservas WHERE fecha_inicio BETWEEN '2026-11-01 00:00:00' AND '2026-11-30 23:59:59';

-- Consulta 2: Salones con capacidad mayor a 50 y disponibles
SELECT * FROM salones WHERE capacidad > 50 AND estado = 'Disponible';

-- Consulta 3: Clientes corporativos y conteo de reservas
SELECT c.id, c.nombre_completo, COUNT(r.id) AS total_reservas
FROM clientes c
LEFT JOIN reservas r ON c.id = r.cliente_id
WHERE c.tipo_cliente = 'Corporativo'
GROUP BY c.id, c.nombre_completo;

-- Ver la vista final
SELECT * FROM vista_resumen_reservas;