#!/usr/bin/env python3
"""
Script para gerar automaticamente toda a estrutura de documentação interativa
do projeto DW E-commerce.

Uso: python generate_docs.py
"""

import os
from pathlib import Path

# Template base para páginas React
REACT_PAGE_TEMPLATE = '''<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title} - DW E-commerce</title>
    <link rel="stylesheet" href="../style.css">
    <style>
        body {{ margin: 0; padding: 0; }}
        #root {{ min-height: 100vh; }}
    </style>
</head>
<body>
    <!-- Navegação -->
    <div class="back-navigation">
        <a href="../index.html" class="back-button">
            ← Voltar ao Menu
        </a>
    </div>
    
    <!-- Container React -->
    <div id="root"></div>
    
    <!-- React via CDN -->
    <script crossorigin src="https://unpkg.com/react@18/umd/react.production.min.js"></script>
    <script crossorigin src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js"></script>
    <script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>
    <script src="https://unpkg.com/lucide@latest"></script>
    
    <!-- Componente React -->
    <script type="text/babel">
        {react_code}
        
        // Render
        const root = ReactDOM.createRoot(document.getElementById('root'));
        root.render(<{component_name} />);
    </script>
</body>
</html>
'''

def create_directory_structure():
    """Cria toda a estrutura de diretórios"""
    dirs = [
        'docs',
        'docs/interactive',
        'docs/assets',
        'docs/assets/images',
        'docs/assets/scripts',
    ]
    
    for dir_path in dirs:
        Path(dir_path).mkdir(parents=True, exist_ok=True)
        print(f"✅ Criado: {dir_path}/")

def create_index_html():
    """Cria a página principal (index.html)"""
    content = '''<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DW E-commerce - Documentação Interativa</title>
    <link rel="stylesheet" href="style.css">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: #333;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 40px 20px;
        }
        
        header {
            text-align: center;
            color: white;
            margin-bottom: 60px;
        }
        
        header h1 {
            font-size: 3em;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        
        header p {
            font-size: 1.2em;
            opacity: 0.95;
        }
        
        .cards-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 30px;
            margin-bottom: 40px;
        }
        
        .card {
            background: white;
            border-radius: 12px;
            padding: 30px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
            transition: transform 0.3s ease, box-shadow 0.3s ease;
            cursor: pointer;
            text-decoration: none;
            color: inherit;
            display: block;
        }
        
        .card:hover {
            transform: translateY(-5px);
            box-shadow: 0 15px 40px rgba(0,0,0,0.3);
        }
        
        .card-icon {
            font-size: 3em;
            margin-bottom: 15px;
        }
        
        .card h3 {
            font-size: 1.5em;
            margin-bottom: 10px;
            color: #667eea;
        }
        
        .card p {
            color: #666;
            line-height: 1.6;
        }
        
        .card-tag {
            display: inline-block;
            background: #e0e7ff;
            color: #667eea;
            padding: 5px 12px;
            border-radius: 20px;
            font-size: 0.85em;
            margin-top: 15px;
            font-weight: 600;
        }
        
        footer {
            text-align: center;
            color: white;
            margin-top: 60px;
            padding: 30px;
            background: rgba(0,0,0,0.2);
            border-radius: 12px;
        }
        
        .github-link {
            display: inline-block;
            margin-top: 20px;
            padding: 12px 24px;
            background: white;
            color: #667eea;
            text-decoration: none;
            border-radius: 8px;
            font-weight: 600;
            transition: transform 0.3s ease;
        }
        
        .github-link:hover {
            transform: scale(1.05);
        }
        
        @media (max-width: 768px) {
            header h1 {
                font-size: 2em;
            }
            .cards-grid {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>📊 Data Warehouse E-commerce</h1>
            <p>Documentação Interativa - Modelagem Dimensional</p>
        </header>
        
        <div class="cards-grid">
            <a href="interactive/views-doc.html" class="card">
                <div class="card-icon">👁️</div>
                <h3>Documentação de Views</h3>
                <p>Explore todas as views auxiliares com exemplos de queries e casos de uso detalhados.</p>
                <span class="card-tag">Interativo</span>
            </a>
            
            <a href="interactive/star-schema.html" class="card">
                <div class="card-icon">⭐</div>
                <h3>Star Schema - Diagrama</h3>
                <p>Visualização do modelo em estrela com dimensões e tabela fato central.</p>
                <span class="card-tag">Visual</span>
            </a>
            
            <a href="interactive/modelo-completo.html" class="card">
                <div class="card-icon">🗄️</div>
                <h3>Modelo Consolidado</h3>
                <p>Modelo dimensional completo com todas as fases: base, vendedores e descontos.</p>
                <span class="card-tag">Completo</span>
            </a>
            
            <a href="interactive/guia-modelagem.html" class="card">
                <div class="card-icon">📚</div>
                <h3>Guia de Modelagem</h3>
                <p>Aprenda os 3 testes, estruturas, decisões de design e glossário completo.</p>
                <span class="card-tag">Educacional</span>
            </a>
            
            <a href="interactive/checklist.html" class="card">
                <div class="card-icon">✅</div>
                <h3>Checklist de Progresso</h3>
                <p>Acompanhe o status de implementação e próximos passos do projeto.</p>
                <span class="card-tag">Gerencial</span>
            </a>
            
            <a href="interactive/descontos-model.html" class="card">
                <div class="card-icon">🏷️</div>
                <h3>Modelo de Descontos</h3>
                <p>Entenda a modelagem de cupons e descontos com múltiplas aplicações.</p>
                <span class="card-tag">Específico</span>
            </a>
        </div>
        
        <footer>
            <h3>🚀 Sobre o Projeto</h3>
            <p>Este é um Data Warehouse completo para E-commerce usando modelagem dimensional (Kimball).</p>
            <p>Desenvolvido com SQL Server, seguindo boas práticas de versionamento e documentação.</p>
            <a href="https://github.com/seu-usuario/dw-ecommerce" class="github-link">
                📂 Ver no GitHub
            </a>
        </footer>
    </div>
</body>
</html>
'''
    
    with open('docs/index.html', 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ Criado: docs/index.html")

def create_style_css():
    """Cria o arquivo de estilos globais"""
    content = '''/* Reset */
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

:root {
    --primary: #667eea;
    --secondary: #764ba2;
    --success: #10b981;
    --danger: #ef4444;
    --warning: #f59e0b;
    --info: #3b82f6;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
    line-height: 1.6;
    color: #333;
}

/* Navegação de volta */
.back-navigation {
    position: fixed;
    top: 20px;
    left: 20px;
    z-index: 1000;
}

.back-button {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    padding: 10px 20px;
    background: white;
    color: var(--primary);
    text-decoration: none;
    border-radius: 8px;
    box-shadow: 0 4px 12px rgba(0,0,0,0.1);
    font-weight: 600;
    transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.back-button:hover {
    transform: translateY(-2px);
    box-shadow: 0 6px 16px rgba(0,0,0,0.15);
}

/* Responsividade */
@media (max-width: 768px) {
    .back-navigation {
        position: relative;
        top: 0;
        left: 0;
        padding: 20px;
    }
}
'''
    
    with open('docs/style.css', 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ Criado: docs/style.css")

def create_readme():
    """Cria o README.md da pasta docs"""
    content = '''# 📚 Documentação Interativa - DW E-commerce

## 🎯 Propósito

Esta pasta contém documentação interativa do projeto Data Warehouse, com visualizações dinâmicas, diagramas e guias educacionais.

## 🚀 Como Visualizar

### Opção 1: Abrir Localmente
```bash
open docs/index.html  # Mac/Linux
start docs/index.html  # Windows
```

### Opção 2: Live Server (VSCode)
1. Instale "Live Server" no VSCode
2. Clique direito em `index.html` → "Open with Live Server"

### Opção 3: Python Server
```bash
cd docs && python -m http.server 8000
# Acesse: http://localhost:8000
```

## 📄 Páginas Disponíveis

- 🏠 **Menu Principal** - Página inicial com navegação
- 👁️ **Views** - Documentação das views SQL
- ⭐ **Star Schema** - Diagrama do modelo
- 🗄️ **Modelo Completo** - Todas dimensões/facts
- 📚 **Guia de Modelagem** - Tutorial interativo
- ✅ **Checklist** - Status do projeto
- 🏷️ **Modelo de Descontos** - Detalhes específicos

## 🛠️ Tecnologias

- React 18 (via CDN)
- Lucide Icons
- Babel Standalone
- CSS3 + HTML5

## 🎨 Customização

Edite `style.css` para mudar cores:
```css
:root {
    --primary: #667eea;
    --secondary: #764ba2;
}
```

## 📞 Suporte

- Email: dw-team@empresa.com
- Slack: #dw-ecommerce
'''
    
    with open('docs/README.md', 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ Criado: docs/README.md")

def create_placeholder_pages():
    """Cria páginas placeholder (você cola o código React depois)"""
    pages = [
        ('views-doc.html', 'Documentação de Views', 'ViewsDocumentation'),
        ('star-schema.html', 'Star Schema', 'StarSchemaERD'),
        ('modelo-completo.html', 'Modelo Consolidado', 'ModeloConsolidado'),
        ('guia-modelagem.html', 'Guia de Modelagem', 'GuiaVisualModelagem'),
        ('checklist.html', 'Checklist de Progresso', 'ChecklistProgresso'),
        ('descontos-model.html', 'Modelo de Descontos', 'DescontosModel'),
    ]
    
    for filename, title, component_name in pages:
        react_code = f'''
        // TODO: Cole aqui o código React do componente {component_name}
        // Você encontra no Artifact correspondente na conversa do Claude
        
        function {component_name}() {{
            return (
                <div style={{{{
                    padding: '40px',
                    textAlign: 'center',
                    minHeight: '100vh',
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                    justifyContent: 'center',
                    background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)'
                }}}}>
                    <div style={{{{
                        background: 'white',
                        padding: '40px',
                        borderRadius: '12px',
                        boxShadow: '0 10px 30px rgba(0,0,0,0.2)',
                        maxWidth: '600px'
                    }}}}>
                        <h1 style={{{{color: '#667eea', marginBottom: '20px'}}}}>
                            {title}
                        </h1>
                        <p style={{{{color: '#666', marginBottom: '20px', lineHeight: '1.6'}}}}>
                            Esta página está pronta para receber o código React do componente.
                        </p>
                        <div style={{{{
                            background: '#f3f4f6',
                            padding: '20px',
                            borderRadius: '8px',
                            textAlign: 'left',
                            fontFamily: 'monospace',
                            fontSize: '14px'
                        }}}}>
                            <strong>Próximos passos:</strong><br/>
                            1. Abra este arquivo: interactive/{filename}<br/>
                            2. Localize o comentário TODO<br/>
                            3. Cole o código do componente {component_name}<br/>
                            4. Salve e recarregue a página
                        </div>
                    </div>
                </div>
            );
        }}
        '''
        
        content = REACT_PAGE_TEMPLATE.format(
            title=title,
            react_code=react_code,
            component_name=component_name
        )
        
        filepath = f'docs/interactive/{filename}'
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"✅ Criado: {filepath}")

def create_gitignore():
    """Cria .gitignore para a pasta docs"""
    content = '''# Arquivos de sistema
.DS_Store
Thumbs.db

# Logs
*.log

# Temporários
*.tmp
*.bak
'''
    
    with open('docs/.gitignore', 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ Criado: docs/.gitignore")

def main():
    """Função principal"""
    print("🚀 Gerando estrutura de documentação interativa...")
    print()
    
    create_directory_structure()
    print()
    
    create_index_html()
    create_style_css()
    create_readme()
    create_placeholder_pages()
    create_gitignore()
    
    print()
    print("=" * 60)
    print("✅ ESTRUTURA CRIADA COM SUCESSO!")
    print("=" * 60)
    print()
    print("📝 Próximos passos:")
    print()
    print("1. Abra cada arquivo em docs/interactive/")
    print("2. Cole o código React correspondente do Claude")
    print("3. Teste abrindo docs/index.html no navegador")
    print("4. Adicione ao Git:")
    print()
    print("   git add docs/")
    print("   git commit -m 'docs: adiciona documentação interativa'")
    print("   git push origin main")
    print()
    print("🌐 Para visualizar agora:")
    print("   open docs/index.html")
    print()

if __name__ == '__main__':
    main()