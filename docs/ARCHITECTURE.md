# 🏗 Arquitectura y Modelo de Datos

## 1. Modelo de Datos (DBML)
El sistema utiliza una arquitectura normalizada para gestionar identidades y capturas de forma independiente.

* **Identities**: Almacena el vector maestro facial (Clustering).
* **Photos**: Almacena el recorte de torso, el número de dorsal (bib_number) y la confianza de detección.

> **Nota**: Puedes ver el diagrama visual en dbdiagram.io usando el código DBML adjunto en este archivo.

## 2. Flujo de Procesamiento
1. **Detección Local**: Se buscan rostros y hombros (5 puntos clave).
2. **Filtro de Calidad**: Si la confianza es > 0.72, se genera el recorte del torso.
3. **Persistencia Local**: Se guarda en SQLite para gestión de cola (QueueScreen).
4. **Sincronización**: Se envía al Worker para clustering y almacenamiento en R2.