#!/bin/bash
# init-project.sh - Script para CRIAR UM NOVO PROJETO Next.js com Docker (usar apenas uma vez)

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# Nome do projeto (primeiro argumento ou padrão 'my-nextjs-app')
PROJECT_NAME=${1:-my-nextjs-app}

log "🎯 Este script irá:"
log "1. Criar um novo projeto Next.js: $PROJECT_NAME"
log "2. Configurar toda estrutura Docker"
log "3. Criar scripts de gerenciamento"
echo
log "⚠️  Este script deve ser executado APENAS UMA VEZ para criar o projeto!"
echo
read -p "Deseja continuar? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    log "❌ Operação cancelada"
    exit 1
fi

# Criar diretório temporário para arquivos Docker
log "📁 Criando diretório temporário para arquivos Docker..."
TEMP_DIR="temp_docker_files"
mkdir -p $TEMP_DIR

# Criar docker-compose.dev.yml no diretório temporário
log "📝 Criando arquivos Docker..."
cat > $TEMP_DIR/docker-compose.dev.yml << 'EOL'
version: '3.8'
services:
  app-dev:
    build:
      context: .
      dockerfile: Dockerfile.dev
    ports:
      - "3000:3000"
    volumes:
      - .:/app
      - /app/node_modules
      - /app/.next
    environment:
      - NODE_ENV=development
    container_name: nextjs-app-dev
    restart: unless-stopped
    stdin_open: true
EOL

cat > $TEMP_DIR/docker-compose.prod.yml << 'EOL'
version: '3.8'
services:
  app-prod:
    build:
      context: .
      dockerfile: Dockerfile.prod
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
    container_name: nextjs-app-prod
    restart: always
EOL

cat > $TEMP_DIR/Dockerfile.dev << 'EOL'
FROM node:20.11.0-alpine

WORKDIR /app

# Atualiza npm de forma silenciosa
RUN npm install -g npm@latest --quiet

# Copia arquivos de dependência
COPY package*.json ./
ENV NODE_ENV=development

# Instala dependências com flags para reduzir warnings
RUN npm install --quiet --no-fund --no-audit

COPY . .

EXPOSE 3000

CMD ["npm", "run", "dev"]
EOL

cat > $TEMP_DIR/Dockerfile.prod << 'EOL'
FROM node:20.11.0-alpine AS deps

WORKDIR /app

RUN npm install -g npm@latest --quiet

COPY package*.json ./
RUN npm install --quiet --no-fund --no-audit --frozen-lockfile

FROM node:20.11.0-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM node:20.11.0-alpine AS runner
WORKDIR /app

ENV NODE_ENV production
ENV PORT 3000

COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

EXPOSE 3000

CMD ["node", "server.js"]
EOL

cat > $TEMP_DIR/docker-scripts.sh << 'EOL'
#!/bin/bash
# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

cleanup_container() {
    local container_name=$1
    if [ "$(docker ps -q -f name=$container_name)" ]; then
        log "🛑 Parando container $container_name..."
        docker stop $container_name
    fi
    if [ "$(docker ps -aq -f name=$container_name)" ]; then
        log "🗑️ Removendo container $container_name..."
        docker rm $container_name
    fi
}

case "$1" in
    "dev")
        case "$2" in
            "start")
                log "🚀 Iniciando ambiente de desenvolvimento..."
                cleanup_container "nextjs-app-dev"
                docker-compose -f docker-compose.dev.yml up --build
                ;;
            "daemon")
                log "🚀 Iniciando ambiente de desenvolvimento em background..."
                cleanup_container "nextjs-app-dev"
                docker-compose -f docker-compose.dev.yml up -d --build
                log "✅ Ambiente iniciado em background!"
                log "📋 Para ver os logs: ./docker-scripts.sh logs dev"
                ;;
            "stop")
                log "🛑 Parando ambiente de desenvolvimento..."
                docker-compose -f docker-compose.dev.yml down
                ;;
            *)
                echo "Uso: ./docker-scripts.sh dev [start|daemon|stop]"
                ;;
        esac
        ;;
    "prod")
        case "$2" in
            "deploy")
                log "🚀 Iniciando deploy em produção..."
                cleanup_container "nextjs-app-prod"
                docker-compose -f docker-compose.prod.yml up -d --build
                log "${GREEN}✅ Deploy realizado com sucesso!${NC}"
                ;;
            "stop")
                log "🛑 Parando ambiente de produção..."
                docker-compose -f docker-compose.prod.yml down
                ;;
            *)
                echo "Uso: ./docker-scripts.sh prod [deploy|stop]"
                ;;
        esac
        ;;
    "logs")
        case "$2" in
            "dev")
                log "📋 Exibindo logs do ambiente de desenvolvimento..."
                docker logs -f nextjs-app-dev
                ;;
            "prod")
                log "📋 Exibindo logs do ambiente de produção..."
                docker logs -f nextjs-app-prod
                ;;
            *)
                echo "Uso: ./docker-scripts.sh logs [dev|prod]"
                ;;
        esac
        ;;
    "status")
        log "ℹ️ Status dos containers:"
        docker ps -a | grep nextjs-app
        ;;
    "cleanup")
        log "🧹 Limpando recursos não utilizados..."
        docker system prune -af --volumes
        log "✅ Limpeza concluída!"
        ;;
    *)
        echo "Uso: ./docker-scripts.sh <comando> [opção]"
        echo "Comandos disponíveis:"
        echo "  dev [start|daemon|stop] - Gerencia ambiente de desenvolvimento"
        echo "  prod [deploy|stop]      - Gerencia ambiente de produção"
        echo "  logs [dev|prod]         - Exibe logs dos ambientes"
        echo "  status                  - Mostra status dos containers"
        echo "  cleanup                 - Limpa recursos não utilizados"
        ;;
esac
EOL

chmod +x $TEMP_DIR/docker-scripts.sh

cat > $TEMP_DIR/next.config.js << 'EOL'
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  reactStrictMode: true,
  images: {
    formats: ['image/avif', 'image/webp'],
  },
  experimental: {
    optimizeCss: true,
    turbotrace: true,
  },
  compress: true,
}

module.exports = nextConfig
EOL

cat > $TEMP_DIR/.gitignore << 'EOL'
# dependencies
/node_modules
/.pnp
.pnp.js

# testing
/coverage

# next.js
/.next/
/out/

# production
/build

# misc
.DS_Store
*.pem

# debug
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# local env files
.env*.local

# vercel
.vercel

# typescript
*.tsbuildinfo
next-env.d.ts
EOL

log "📦 Criando aplicação Next.js..."
# Criar o app Next.js usando Docker
docker run --rm -it \
  -v $(pwd):/app \
  -w /app \
  node:20.11.0-alpine \
  sh -c "npx create-next-app@latest $PROJECT_NAME --ts --tailwind --eslint --app --src-dir --import-alias --use-npm --no-git && \
         cd $PROJECT_NAME && npm install --quiet --no-fund --no-audit"

# Mover arquivos Docker para o diretório do projeto
log "📝 Movendo arquivos Docker para o projeto..."
mv $TEMP_DIR/* $PROJECT_NAME/
rm -rf $TEMP_DIR

log "${GREEN}✅ Projeto criado com sucesso!${NC}"
log "
🚀 PRÓXIMOS PASSOS:

1. Entre no diretório do projeto:
   cd $PROJECT_NAME

2. Para DESENVOLVER, use:
   ./docker-scripts.sh dev start    # inicia com logs
   ./docker-scripts.sh dev daemon   # inicia em background

3. Para ver os LOGS:
   ./docker-scripts.sh logs dev

4. Para ver o STATUS:
   ./docker-scripts.sh status

❗ LEMBRE-SE: Este script init-project.sh não deve ser executado novamente!
   Use apenas docker-scripts.sh para gerenciar seu projeto daqui pra frente.
"