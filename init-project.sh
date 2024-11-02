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

# Criar diretório do projeto
log "📁 Criando diretório do projeto..."
mkdir -p $PROJECT_NAME
cd $PROJECT_NAME

# [... todos os outros comandos de criação de arquivos como antes ...]

# Ao invés do wget, criar docker-scripts.sh diretamente
log "📝 Criando script de gerenciamento docker-scripts.sh..."
cat > docker-scripts.sh << 'EOL'
#!/bin/bash
# Scripts para GERENCIAR o projeto (usar sempre que precisar)

# [... conteúdo do docker-scripts.sh que mostrei anteriormente ...]
EOL

chmod +x docker-scripts.sh

log "📦 Criando aplicação Next.js..."
# Criar o app Next.js usando Docker
docker run --rm -it \
  -v $(pwd):/app \
  -w /app \
  node:latest \
  bash -c "npx create-next-app@latest . --ts --tailwind --eslint --app --src-dir --import-alias --use-npm --no-git --force"

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

5. Para PARAR:
   ./docker-scripts.sh dev stop

❗ LEMBRE-SE: Este script init-project.sh não deve ser executado novamente!
   Use apenas docker-scripts.sh para gerenciar seu projeto daqui pra frente.
"