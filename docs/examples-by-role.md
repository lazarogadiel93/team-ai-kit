# Ejemplos por Rol

> Ejemplos reales de como Team AI Kit cambia el comportamiento del AI para cada rol.

Todos los roles reciben 5 skills compartidos (architecture, code-quality, debug, thinking, performance). Aca mostramos como los skills especificos de cada rol impactan el codigo generado.

---

## Frontend

**Skills**: react, nextjs | **Pack**: frontend/rules.md

### Componentes y Data Fetching

<table>
<tr>
<th>❌ Sin estandarizar</th>
<th>✅ Con Team AI Kit</th>
</tr>
<tr>
<td>

```tsx
// Componente monolitico, any, fetch en cliente
const Products = () => {
  const [data, setData] = useState<any[]>([]);
  useEffect(() => {
    fetch('/api/products')
      .then(r => r.json())
      .then(setData);
  }, []);
  return data.map((p, i) =>
    <div key={i}>{p.name}</div>);
}
```

</td>
<td>

```tsx
// Server Component + separacion
export default async function ProductsPage() {
  const products = await getProducts();
  return <ProductList products={products} />;
}

// Presentacional, tipado, key estable
interface Props { products: Product[] }
export function ProductList({ products }: Props) {
  return products.map(p =>
    <ProductCard key={p.id} product={p} />);
}
```

</td>
</tr>
</table>

**Que aplica el AI automaticamente:**

- TypeScript estricto: cero `any`, tipos de retorno explicitos
- Server Components por defecto en Next.js, `use client` solo cuando es necesario
- Cada feature es un modulo cerrado, sin imports cruzados entre features
- Componentes presentacionales puros, logica de negocio en hooks/services
- Validacion con Zod, schemas co-localizados con la feature

---

## Backend Node.js

**Skills**: api-design, testing | **Pack**: backend-node/rules.md

### Estructura de API

<table>
<tr>
<th>❌ Sin estandarizar</th>
<th>✅ Con Team AI Kit</th>
</tr>
<tr>
<td>

```typescript
// Todo en el controller, SQL crudo
app.get('/users/:id', async (req, res) => {
  const user = await db.query(
    'SELECT * FROM users WHERE id = $1',
    [req.params.id]
  );
  res.json(user);
});
```

</td>
<td>

```typescript
// Controller: valida y delega
async getById(req: Request, res: Response) {
  const { id } = userIdSchema.parse(req.params);
  const user = await this.service.getById(id);
  res.json(user);
}

// Service: logica de negocio
async getById(id: string): Promise<User> {
  const user = await this.repo.findById(id);
  if (!user) throw new NotFoundError('User');
  return user;
}
```

</td>
</tr>
</table>

**Que aplica el AI automaticamente:**

- Separacion en capas: routes → controllers → services → repositories
- Validacion con Zod en el borde de entrada, no dispersa
- Error handling centralizado con clases tipadas
- Inyeccion de dependencias para facilitar testing
- Secrets y configs siempre via variables de entorno

---

## DevOps

**Skills**: cicd, monitoring | **Pack**: devops/rules.md

### Dockerfiles

<table>
<tr>
<th>❌ Sin estandarizar</th>
<th>✅ Con Team AI Kit</th>
</tr>
<tr>
<td>

```dockerfile
# Sin multi-stage, root, sin health check
FROM node:latest
WORKDIR /app
COPY . .
RUN npm install
EXPOSE 3000
CMD ["npm", "start"]

# Imagen pesada, no reproducible,
# corre como root, sin health check
```

</td>
<td>

```dockerfile
# Multi-stage, version fija, non-root
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

FROM node:20-alpine AS runtime
RUN adduser -u 1001 -D appuser
COPY --from=builder /app/dist ./dist
USER appuser
HEALTHCHECK CMD wget -qO- localhost:3000/health
CMD ["node", "dist/index.js"]
```

</td>
</tr>
</table>

### Pipelines CI/CD

<table>
<tr>
<th>❌ Sin estandarizar</th>
<th>✅ Con Team AI Kit</th>
</tr>
<tr>
<td>

```yaml
# Sin stages, sin fail-fast, secret hardcoded
trigger: [main]
steps:
  - script: npm test
  - script: docker build -t app:latest .
  - script: docker push app:latest
    env:
      REGISTRY_PASS: 's3cret123'  # en el repo
```

</td>
<td>

```yaml
stages:
  - stage: Validate  # lint + test
    jobs:
      - script: npm run lint
      - script: npm test -- --coverage

  - stage: Build
    dependsOn: Validate  # fail-fast
    jobs:
      - script: docker build -t app:$(Build.BuildId) .

  - stage: Deploy
    condition: succeeded()
    variables:
      - group: production-secrets  # Key Vault
```

</td>
</tr>
</table>

**Que aplica el AI automaticamente:**

- Pipelines con etapas claras: lint → test → build → deploy, con fail-fast entre stages
- Dockerfiles multi-stage, imagen base con version explicita, usuario non-root, health check
- Secrets nunca en el repo -- variable groups, Key Vault o env vars del CI
- Logging estructurado (JSON) con request ID para trazabilidad end-to-end
- Metricas RED (Rate, Errors, Duration) como estandar de observabilidad
- Dry-run / plan antes de apply en produccion, cambios reversibles siempre

---

## QA / Analistas Funcionales

**Skills compartidos**: thinking, debug (especialmente relevantes para este rol)

Para QA y funcionales, el impacto no es en el codigo generado sino en **como el AI analiza problemas**. Los skills de thinking y debug cambian radicalmente el comportamiento:

### Investigacion de bugs

<table>
<tr>
<th>❌ Sin estandarizar</th>
<th>✅ Con Team AI Kit</th>
</tr>
<tr>
<td>

**Analista:** Los usuarios reportan que el checkout falla intermitentemente

**AI:** Aqui esta el codigo para agregar un retry al checkout con exponential backoff...

*(Salto directo al codigo sin entender el problema)*

</td>
<td>

**Analista:** Los usuarios reportan que el checkout falla intermitentemente

**AI:** Antes de proponer soluciones, necesito entender el alcance:
- ¿Falla en un paso especifico (pago, stock, direccion)?
- ¿Hay patron horario o de carga?
- ¿Los logs muestran timeouts, errores 4xx o 5xx?
- ¿Algun cambio reciente en el servicio de pagos?

**Analista:** Solo en el paso de pago, en horarios pico

**AI:** Patron claro: fallo bajo carga → posible race condition o pool de conexiones agotado en el servicio de pagos. Verifiquemos los logs del gateway...

*(Narrowing sistematico hasta la causa raiz)*

</td>
</tr>
</table>

**Que cambia en el comportamiento del AI:**

- **Skill thinking**: El AI descompone el problema antes de proponer. Pregunta ¿cual es el problema real? ¿que supuestos hay? ¿hay una solucion mas simple?
- **Skill debug**: Narrowing sistematico -- aislar capa → funcion → input → causa raiz. Fix minimo, sin refactors durante debug
- **engram**: Las investigaciones de bugs quedan guardadas. Si un analista investiga una race condition y documenta la causa raiz, meses despues otro analista con sintomas similares recibe esa informacion automaticamente del AI

---

## Skill de ejemplo: como se ve internamente

Este es un extracto real del skill `debug` que todos los roles reciben:

```markdown
## Critical Patterns

### Pattern 1: Reproducir antes de fijar

Antes de cambiar cualquier codigo, reproduce el error de forma aislada:
1. ¿El error ocurre siempre o intermitentemente?
2. ¿Que input lo provoca?
3. ¿Que version de Node/deps esta activa?

### Pattern 2: Narrowing sistematico

Error observado
    └── ¿En que capa ocurre? (UI / Domain / Data / Infra)
            └── ¿Que funcion exacta falla? (stack trace)
                    └── ¿Con que input? (log de parametros)
                            └── Causa raiz identificada

### Pattern 3: Fix minimo -- no refactor durante debug

❌ MAL: "Ya que estoy debuggeando, refactorizo tambien"

✅ BIEN:
  1. Fix minimo que arregla el bug
  2. Test que verifica el fix
  3. Commit del fix
  4. Refactor en PR separado si es necesario
```

Los skills son archivos markdown que el AI carga automaticamente segun el contexto. No hay magia -- son instrucciones claras que el AI sigue porque estan inyectadas en su contexto.

---

← [Volver al README](../README.md)
