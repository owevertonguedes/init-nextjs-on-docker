#!/bin/bash
# init-project.sh - Configuração automática de projeto Next.js com Docker

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Verificar e instalar dependências do sistema
install_system_dependencies() {
    log "🔍 Verificando dependências do sistema..."
    
    if ! command -v curl &> /dev/null; then
        log "Instalando curl..."
        apt-get update && apt-get install -y curl
    fi

    if ! command -v git &> /dev/null; then
        log "Instalando git..."
        apt-get update && apt-get install -y git
    fi
}

# Instalar e configurar Docker
setup_docker() {
    if ! command -v docker &> /dev/null; then
        log "Instalando Docker..."
        curl -fsSL https://get.docker.com | sh
        systemctl start docker
        systemctl enable docker
        
        # Adicionar usuário atual ao grupo docker para evitar uso de sudo
        usermod -aG docker $SUDO_USER
        
        # Configurar para usar BuildKit por padrão
        mkdir -p /etc/docker
        echo '{"features":{"buildkit":true}}' > /etc/docker/daemon.json
        systemctl restart docker
    fi

    # Instalar versão mais recente do Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log "Instalando Docker Compose..."
        LATEST_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -o -P '(?<="tag_name": ").+(?=")')
        curl -L "https://github.com/docker/compose/releases/download/${LATEST_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
}

# Verificar permissões e dependências
check_prerequisites() {
    if [ "$EUID" -ne 0 ]; then 
        error "Este script precisa ser executado como root (sudo)"
        exit 1
    fi

    install_system_dependencies
    setup_docker
    
    log "✅ Todas as dependências estão instaladas!"
}

# Nome do projeto
PROJECT_NAME=${1:-my-nextjs-app}

log "🎯 Criando projeto Next.js com Docker: $PROJECT_NAME"
read -p "Deseja continuar? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "❌ Operação cancelada"
    exit 1
fi

check_prerequisites

# Criar projeto Next.js
log "📦 Criando aplicação Next.js..."
docker run --rm -it \
  -v $(pwd):/app \
  -w /app \
  -u $(id -u):$(id -g) \
  node:20.11.0-alpine \
  sh -c "npm create next-app@latest $PROJECT_NAME --ts --tailwind --eslint --app --src-dir --import-alias --use-npm"

cd $PROJECT_NAME

# Criar Dockerfile.dev
cat > Dockerfile.dev << 'EOL'
FROM node:20.11.0-alpine

WORKDIR /app

# Instalar dependências do sistema
RUN apk add --no-cache libc6-compat

# Copiar apenas os arquivos necessários para instalação
COPY package*.json ./
ENV NODE_ENV=development

# Instalar dependências
RUN npm install

COPY . .

EXPOSE 3000

CMD ["npm", "run", "dev"]
EOL

# Criar Dockerfile.prod
cat > Dockerfile.prod << 'EOL'
FROM node:20.11.0-alpine AS deps

WORKDIR /app

# Instalar dependências do sistema
RUN apk add --no-cache libc6-compat

COPY package*.json ./
RUN npm install --production

FROM node:20.11.0-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Construir com variáveis de ambiente otimizadas
ENV NEXT_TELEMETRY_DISABLED 1
ENV NODE_ENV production
RUN npm run build

FROM node:20.11.0-alpine AS runner
WORKDIR /app

ENV NODE_ENV production
ENV NEXT_TELEMETRY_DISABLED 1
ENV PORT 3000

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

CMD ["node", "server.js"]
EOL

# Criar docker-compose.dev.yml
cat > docker-compose.dev.yml << 'EOL'
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

# Criar docker-compose.prod.yml
cat > docker-compose.prod.yml << 'EOL'
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

# Criar CLI de gerenciamento
cat > docker-cli.sh << 'EOL'
#!/bin/bash

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

case "$1" in
    # Comandos de Desenvolvimento
    "dev:start")
        log "🚀 Iniciando ambiente de desenvolvimento..."
        docker-compose -f docker-compose.dev.yml up --build
        ;;
    "dev:daemon")
        log "🚀 Iniciando ambiente de desenvolvimento em background..."
        docker-compose -f docker-compose.dev.yml up -d --build
        success "Ambiente iniciado! Use './docker-cli.sh logs' para ver os logs"
        ;;
    "dev:stop")
        log "🛑 Parando ambiente de desenvolvimento..."
        docker-compose -f docker-compose.dev.yml down
        ;;

    # Comandos de Produção
    "prod:deploy")
        log "🚀 Realizando deploy em produção..."
        docker-compose -f docker-compose.prod.yml up -d --build
        success "Deploy realizado com sucesso!"
        ;;
    "prod:stop")
        log "🛑 Parando ambiente de produção..."
        docker-compose -f docker-compose.prod.yml down
        ;;
    "prod:logs")
        log "📋 Exibindo logs de produção..."
        docker logs -f nextjs-app-prod
        ;;

    # Comandos de Logs
    "logs")
        log "📋 Exibindo logs de desenvolvimento..."
        docker logs -f nextjs-app-dev
        ;;

    # Comandos de Manutenção
    "clean")
        log "🧹 Limpando recursos não utilizados..."
        docker system prune -af --volumes
        success "Limpeza concluída!"
        ;;
    "restart")
        log "🔄 Reiniciando containers..."
        docker-compose -f docker-compose.dev.yml restart
        success "Containers reiniciados!"
        ;;
    "rebuild")
        log "🔨 Reconstruindo containers..."
        docker-compose -f docker-compose.dev.yml up -d --build --force-recreate
        success "Containers reconstruídos!"
        ;;

    # Comando de Status
    "status")
        log "ℹ️  Status dos containers:"
        docker ps -a | grep nextjs-app
        ;;

    *)
        echo "Uso: ./docker-cli.sh <comando>"
        echo ""
        echo "Comandos de Desenvolvimento:"
        echo "  dev:start   - Inicia ambiente de desenvolvimento"
        echo "  dev:daemon  - Inicia desenvolvimento em background"
        echo "  dev:stop    - Para ambiente de desenvolvimento"
        echo ""
        echo "Comandos de Produção:"
        echo "  prod:deploy - Realiza deploy em produção"
        echo "  prod:stop   - Para ambiente de produção"
        echo "  prod:logs   - Mostra logs de produção"
        echo ""
        echo "Comandos de Logs:"
        echo "  logs        - Mostra logs de desenvolvimento"
        echo ""
        echo "Comandos de Manutenção:"
        echo "  clean       - Limpa recursos não utilizados"
        echo "  restart     - Reinicia containers"
        echo "  rebuild     - Reconstrói containers"
        echo "  status      - Mostra status dos containers"
        ;;
esac
EOL

chmod +x docker-cli.sh

# Atualizar next.config.js
cat > next.config.js << 'EOL'
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone'
}

module.exports = nextConfig
EOL

log "${GREEN}✅ Projeto criado com sucesso!${NC}"
log "
🚀 PRÓXIMOS PASSOS:

1. cd $PROJECT_NAME

2. Para desenvolvimento:
   ./docker-cli.sh dev:start   # inicia com logs
   ./docker-cli.sh dev:daemon  # inicia em background
   ./docker-cli.sh dev:stop    # para o ambiente

3. Para produção:
   ./docker-cli.sh prod:deploy # deploy em produção
   ./docker-cli.sh prod:stop   # para produção
   ./docker-cli.sh prod:logs   # logs de produção

4. Outros comandos úteis:
   ./docker-cli.sh status      # status dos containers
   ./docker-cli.sh logs        # logs de desenvolvimento
   ./docker-cli.sh clean       # limpa recursos
   ./docker-cli.sh rebuild     # reconstrói containers

💡 Use ./docker-cli.sh sem argumentos para ver todos os comandos disponíveis
"