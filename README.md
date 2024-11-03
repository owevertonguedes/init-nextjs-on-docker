# 🚀 Next.js Docker Development Environment

Uma configuração otimizada para desenvolvimento Next.js com Docker, incluindo ambientes de desenvolvimento e produção completamente containerizados.

## 🌟 Características

- ⚡ Ambiente de desenvolvimento completamente dockerizado
- 🔄 Hot reload funcionando perfeitamente
- 🛠️ Configuração de produção otimizada com multi-stage builds
- 📦 Node.js latest
- 🎯 TypeScript, Tailwind CSS, e ESLint incluídos
- 🚀 Scripts simplificados para gerenciamento

## 🏗️ Estrutura do Projeto

```
.
├── 🐳 Dockerfile.dev          # Configuração Docker para desenvolvimento
├── 🐳 Dockerfile.prod         # Configuração Docker para produção
├── 📄 docker-compose.dev.yml  # Compose para desenvolvimento
├── 📄 docker-compose.prod.yml # Compose para produção
├── 🛠️ docker-scripts.sh       # Scripts de gerenciamento
└── ⚙️ next.config.js          # Configurações do Next.js
```

## 🚀 Começando

### Primeira Vez: Criar Novo Projeto

```bash
# Clone este repositório
git clone https://github.com/owevertonguedes/init-nextjs-on-docker

# Execute o script de inicialização
./init-project.sh nome-do-projeto

# Entre no diretório do projeto
cd nome-do-projeto
```

### Uso Diário

```bash
# Iniciar desenvolvimento com logs
./docker-scripts.sh dev start

# Iniciar em background
./docker-scripts.sh dev daemon

# Ver logs
./docker-scripts.sh logs dev

# Parar ambiente
./docker-scripts.sh dev stop

# Ver status
./docker-scripts.sh status

# Fazer deploy em produção
./docker-scripts.sh prod deploy
```

## 🔧 Comandos Disponíveis

- `dev start`: Inicia ambiente de desenvolvimento com logs
- `dev daemon`: Inicia em background
- `dev stop`: Para o ambiente de desenvolvimento
- `prod deploy`: Deploy em produção
- `prod stop`: Para o ambiente de produção
- `logs [dev|prod]`: Visualiza logs
- `status`: Status dos containers
- `cleanup`: Limpa recursos não utilizados

## 🌐 Acessando a Aplicação

- Desenvolvimento: http://localhost:3000
- Produção: http://localhost:3000 (ou sua porta configurada)

## 📝 Notas Importantes

1. O script `init-project.sh` deve ser executado apenas UMA VEZ para criar o projeto
2. Use `docker-scripts.sh` para gerenciamento diário
3. Ambiente de desenvolvimento inclui hot reload
4. Produção usa build otimizado com multi-stage

## 🤝 Contribuindo

1. Faça o fork do projeto
2. Crie sua feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## 📜 Licença

Distribuído sob a licença MIT. Veja `LICENSE` para mais informações.
