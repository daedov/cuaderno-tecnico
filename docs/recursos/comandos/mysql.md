## MySQL
| Comando | Descripción |
|---------|-------------|
| `mysql -u <usuario> -p` | Conectarse al servidor MySQL |
| `mysql -u <usuario> -p -h <host>` | Conectarse a un host remoto |
| `SHOW DATABASES;` | Listar bases de datos |
| `CREATE DATABASE <nombre>;` | Crear una base de datos |
| `DROP DATABASE <nombre>;` | Eliminar una base de datos |
| `USE <base_de_datos>;` | Seleccionar base de datos activa |
| `SHOW TABLES;` | Listar tablas de la base de datos actual |
| `DESCRIBE <tabla>;` | Ver estructura de una tabla |
| `CREATE TABLE <tabla> (...);` | Crear una tabla |
| `ALTER TABLE <tabla> ADD <columna> <tipo>;` | Agregar columna a una tabla |
| `DROP TABLE <tabla>;` | Eliminar una tabla |
| `SELECT * FROM <tabla>;` | Consultar todos los registros |
| `SELECT * FROM <tabla> WHERE <condición>;` | Consultar con filtro |
| `INSERT INTO <tabla> (col1, col2) VALUES (v1, v2);` | Insertar un registro |
| `UPDATE <tabla> SET <col>=<valor> WHERE <condición>;` | Actualizar registros |
| `DELETE FROM <tabla> WHERE <condición>;` | Eliminar registros |
| `SHOW PROCESSLIST;` | Ver procesos/consultas activas |
| `SHOW GRANTS FOR '<usuario>'@'<host>';` | Ver permisos de un usuario |
| `GRANT ALL PRIVILEGES ON <bd>.* TO '<usuario>'@'<host>';` | Otorgar permisos |
| `FLUSH PRIVILEGES;` | Recargar tabla de privilegios |
| `mysqldump -u <usuario> -p <bd> > backup.sql` | Exportar (respaldar) una base de datos |
| `mysql -u <usuario> -p <bd> < backup.sql` | Importar/restaurar una base de datos |