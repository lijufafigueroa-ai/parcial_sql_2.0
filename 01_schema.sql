-- ============================================================================
-- 01_schema.sql: CREACIÓN DE BASE DE DATOS Y TABLAS
-- ============================================================================

CREATE DATABASE IF NOT EXISTS db_reservas_eventos;
USE db_reservas_eventos;

CREATE TABLE IF NOT EXISTS salones (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    capacidad INT NOT NULL,
    precio_hora DECIMAL(10,2) NOT NULL,
    estado ENUM('Disponible', 'Ocupado', 'En mantenimiento') NOT NULL DEFAULT 'Disponible',
    encargado VARCHAR(100) NOT NULL
);

CREATE TABLE IF NOT EXISTS clientes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre_completo VARCHAR(150) NOT NULL,
    identificacion VARCHAR(30) NOT NULL UNIQUE,
    telefono VARCHAR(20),
    correo VARCHAR(100),
    tipo_cliente ENUM('Individual', 'Corporativo') NOT NULL DEFAULT 'Individual'
);

CREATE TABLE IF NOT EXISTS reservas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    salon_id INT NOT NULL,
    cliente_id INT NOT NULL,
    fecha_inicio DATETIME NOT NULL,
    fecha_fin DATETIME NOT NULL,
    total_horas DECIMAL(8,2) NOT NULL,
    valor_total DECIMAL(10,2) NOT NULL DEFAULT 0,
    estado_reserva ENUM('Pendiente', 'Confirmada', 'Cancelada') NOT NULL DEFAULT 'Pendiente',
    FOREIGN KEY (salon_id) REFERENCES salones(id),
    FOREIGN KEY (cliente_id) REFERENCES clientes(id)
);

CREATE TABLE IF NOT EXISTS pagos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    reserva_id INT NOT NULL,
    fecha_pago DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    monto_pagado DECIMAL(10,2) NOT NULL,
    metodo_pago ENUM('Efectivo', 'Tarjeta', 'Transferencia') NOT NULL,
    FOREIGN KEY (reserva_id) REFERENCES reservas(id)
);

CREATE TABLE IF NOT EXISTS auditoria_precios (
    id INT AUTO_INCREMENT PRIMARY KEY,
    salon_id INT NOT NULL,
    usuario VARCHAR(100) NOT NULL,
    fecha_cambio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    precio_anterior DECIMAL(10,2) NOT NULL,
    precio_nuevo DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (salon_id) REFERENCES salones(id)
);