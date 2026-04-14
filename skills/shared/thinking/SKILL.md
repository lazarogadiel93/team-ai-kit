---
name: thinking
description: >
  Patrones de análisis cognitivo para descomponer problemas complejos antes de proponer soluciones.
  Trigger: Al analizar un problema, al evaluar alternativas, al detectar riesgos o cuando el input es ambiguo.
metadata:
  author: team-ai-kit
  version: "1.0"
---

## When to Use

Carga este skill cuando:

- El usuario describe un problema o feature sin definición clara
- Hay múltiples alternativas posibles y necesitas evaluar pros/contras
- Detectas riesgos ocultos en el enfoque propuesto
- El scope parece más grande de lo necesario (posible overengineering)

---

## Critical Patterns

### Pattern 1: Descomposición antes de solución

Antes de proponer cualquier solución, define con precisión:

1. **¿Cuál es el problema real?** (no el síntoma)
2. **¿Qué supuestos se están haciendo?**
3. **¿Qué riesgos existen en cada alternativa?**
4. **¿Hay una solución más simple?**

### Pattern 2: Priorizar simplicidad

```
Complexidad innecesaria → deuda técnica
Solución simple que funciona > solución elegante que no existe aún
```

### Pattern 3: Validar antes de construir

```
idea → hipótesis → validación mínima → implementación
```

No abstraer sin al menos 2 casos reales que lo requieran.

---

## Anti-Patterns

### Don't: Saltar directo a la solución

```
❌ Usuario: "necesito autenticación"
   Agente: "Aquí está el código de autenticación..."

✅ Usuario: "necesito autenticación"
   Agente: "¿Qué tipo? ¿Session-based, JWT, OAuth? ¿Quién es el usuario?"
```

### Don't: Abstraer prematuramente

```
❌ Crear BaseRepository<T> cuando solo tienes un caso de uso

✅ Implementar directamente, extraer abstracción al segundo caso real
```

---

## Quick Reference

| Pregunta                         | Acción                                         |
| -------------------------------- | ---------------------------------------------- |
| ¿El problema está bien definido? | Si no → preguntar antes de proceder            |
| ¿Hay alternativas más simples?   | Siempre explorar al menos 2 caminos            |
| ¿Cuánto cuesta el error?         | Evaluar reversibilidad de la decisión          |
| ¿Es realmente necesario ahora?   | YAGNI — no construir para el futuro hipotético |
