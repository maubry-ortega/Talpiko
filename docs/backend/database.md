# 🗃️ ¡Gestiona Datos con Talpo en Talpiko Framework!

¡Sumérgete en la gestión de datos con el módulo `db.nim` de **Talpo**! Con un ORM ligero, query builder type-safe y migraciones, organiza bases de datos con Nim puro, listo para el 12 de julio de 2025 a las 15:58.

## 🚀 ¿Qué hace el Módulo de Base de Datos?
- **Query Builder**: Construye consultas SQL seguras.
- **Migraciones**: Automatiza cambios en la base de datos.
- **Soporte Múltiple**: SQLite, PostgreSQL con abstracción.
- **ORM Ligero**: Define modelos tipados (`User`).

## 🛠️ Cómo Usarlo
Define un modelo y consulta:
```nim
type User = object
  id: int
  name: string
db.query:
  select("id", "name")
  from("users")
  where("id" == 1)
```

Ejecuta una migración:
```nim
migration "create_users":
  createTable("users"):
    id: int primary key
    name: string not null
```

## 🌱 Planes a Futuro
- Añade `talpiko db seed` para datos iniciales.
- Optimiza consultas para alto rendimiento.

## 🎉 Ejemplo Práctico
Busca un usuario:
```nim
let user = db.query:
  select("name")
  from("users")
  where("id" == 1)
echo user[0].name # "Talpo"
```

## 🎨 Un Toque Visual
```
   [Modelo] --> [Query Builder] --> [Migración]
      ↓           ↓               ↓
   [Validar] --> [Consulta] --> [¡Datos Listos!]
```

**¡Organiza tu backend con Talpo y domina los datos! 🐾**