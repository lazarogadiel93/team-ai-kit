# Pack: Python

> Reglas y convenciones para desarrolladores Python del equipo.

---

## Architecture Rules

- Organización por dominio: cada módulo es un paquete con `__init__.py` explícito
- Separación de responsabilidades: routers/views → services → repositories
- Dependency injection via constructores o FastAPI Depends()
- Configuración centralizada con pydantic-settings o python-decouple
- Evitar imports circulares: diseñar la jerarquía de dependencias desde el inicio
- Type hints obligatorios en funciones públicas

## Code Quality Rules

- Type hints obligatorios en todas las funciones públicas
- Docstrings en funciones/clases de dominio (una línea basta para funciones simples)
- Nombres en snake_case, clases en PascalCase
- Funciones cortas y con responsabilidad única
- Evitar mutación de parámetros de entrada
- Nunca ignorar excepciones en silencio (bare `except: pass` prohibido)
- f-strings para formateo de strings, nunca concatenación con +

## Thinking Rules

- Preferir la solución más legible sobre la más "pythónica" si hay trade-off de claridad
- Evitar abstracciones prematuras: primero funciona, luego abstrae
- Pensar en el contrato de la función (inputs/outputs) antes de implementar
- Considerar el contexto de ejecución: sync vs async, CPU-bound vs I/O-bound
- Validar supuestos de tipos en el borde del sistema, no en cada función interna
