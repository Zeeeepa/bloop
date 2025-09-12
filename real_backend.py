#!/usr/bin/env python3
"""
Real Backend for Bloop with OpenAI and GitHub API Integration
"""

import os
import json
import asyncio
import logging
from pathlib import Path
from typing import Dict, List, Any, Optional
from datetime import datetime

import aiohttp
from aiohttp import web, ClientSession
from aiohttp.web import Request, Response, json_response
from aiohttp_cors import setup as cors_setup, ResourceOptions
import openai
from github import Github
import tiktoken

# Load environment variables
def load_env():
    env_file = Path('.env')
    if env_file.exists():
        with open(env_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    os.environ[key] = value

load_env()

# Configuration
CONFIG = {
    'host': '127.0.0.1',
    'port': 7878,
    'openai_api_key': os.getenv('OPENAI_API_KEY'),
    'github_token': os.getenv('GITHUB_TOKEN'),
    'openai_model': 'gpt-3.5-turbo',
    'max_tokens': 2048,
    'temperature': 0.7,
    'github_repos': ['Zeeeepa/bloop']
}

# Global clients
github_client = None
openai_client = None

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class RealBackend:
    def __init__(self):
        self.github = None
        self.openai_client = None
        self.session = None
        self.setup_clients()
    
    def setup_clients(self):
        """Initialize API clients"""
        try:
            # GitHub client
            if CONFIG['github_token']:
                self.github = Github(CONFIG['github_token'])
                logger.info("✅ GitHub client initialized")
            else:
                logger.warning("⚠️ GitHub token not found")
            
            # OpenAI client
            if CONFIG['openai_api_key']:
                openai.api_key = CONFIG['openai_api_key']
                self.openai_client = openai
                logger.info("✅ OpenAI client initialized")
            else:
                logger.warning("⚠️ OpenAI API key not found")
                
        except Exception as e:
            logger.error(f"❌ Error setting up clients: {e}")

    async def health_check(self, request: Request) -> Response:
        """Health check endpoint"""
        status = {
            'status': 'healthy',
            'timestamp': datetime.now().isoformat(),
            'services': {
                'github': bool(self.github),
                'openai': bool(self.openai_client),
            }
        }
        return json_response(status)

    async def search_code(self, request: Request) -> Response:
        """Search code using GitHub API and OpenAI"""
        try:
            data = await request.json()
            query = data.get('q', '')
            
            if not query:
                return json_response({'error': 'Query parameter required'}, status=400)
            
            results = []
            
            # Search GitHub repositories
            if self.github:
                try:
                    for repo_name in CONFIG['github_repos']:
                        repo = self.github.get_repo(repo_name)
                        
                        # Use GitHub's search API for better results
                        try:
                            search_results = self.github.search_code(f"{query} repo:{repo_name}")
                            for result in search_results[:10]:  # Limit results
                                results.append({
                                    'type': 'code',
                                    'path': result.path,
                                    'name': result.name,
                                    'url': result.html_url,
                                    'repository': repo_name,
                                    'score': result.score if hasattr(result, 'score') else 0.8,
                                    'snippet': result.text_matches[0]['fragment'] if hasattr(result, 'text_matches') and result.text_matches else None
                                })
                        except Exception as search_error:
                            logger.warning(f"GitHub code search failed: {search_error}")
                            
                            # Fallback to browsing repository contents
                            def search_contents(contents, path=""):
                                for content in contents:
                                    if content.type == "file":
                                        if query.lower() in content.name.lower() or query.lower() in content.path.lower():
                                            results.append({
                                                'type': 'file',
                                                'path': content.path,
                                                'name': content.name,
                                                'url': content.html_url,
                                                'repository': repo_name,
                                                'score': 0.7
                                            })
                                    elif content.type == "dir" and len(path.split('/')) < 3:  # Limit depth
                                        try:
                                            sub_contents = repo.get_contents(content.path)
                                            search_contents(sub_contents, content.path)
                                        except:
                                            pass
                            
                            root_contents = repo.get_contents("")
                            search_contents(root_contents)
                            
                except Exception as e:
                    logger.error(f"GitHub search error: {e}")
            
            # Enhance results with OpenAI if available
            if self.openai_client and results:
                try:
                    # Create a summary of search results using OpenAI
                    files_summary = "\n".join([f"- {r['path']}" for r in results[:3]])
                    
                    response = await asyncio.to_thread(
                        openai.ChatCompletion.create,
                        model=CONFIG['openai_model'],
                        messages=[
                            {
                                "role": "system", 
                                "content": "You are a code search assistant. Provide brief, helpful descriptions of code files."
                            },
                            {
                                "role": "user", 
                                "content": f"Describe these code files found for query '{query}':\n{files_summary}"
                            }
                        ],
                        max_tokens=200,
                        temperature=0.3
                    )
                    
                    ai_summary = response.choices[0].message.content
                    
                    # Add AI summary to response
                    return json_response({
                        'results': results,
                        'ai_summary': ai_summary,
                        'query': query,
                        'total': len(results)
                    })
                    
                except Exception as e:
                    logger.error(f"OpenAI enhancement error: {e}")
            
            return json_response({
                'results': results,
                'query': query,
                'total': len(results)
            })
            
        except Exception as e:
            logger.error(f"Search error: {e}")
            return json_response({'error': str(e)}, status=500)

    async def get_repositories(self, request: Request) -> Response:
        """Get repository information"""
        try:
            repos = []
            
            if self.github:
                for repo_name in CONFIG['github_repos']:
                    try:
                        repo = self.github.get_repo(repo_name)
                        repos.append({
                            'name': repo.name,
                            'full_name': repo.full_name,
                            'description': repo.description,
                            'language': repo.language,
                            'stars': repo.stargazers_count,
                            'forks': repo.forks_count,
                            'url': repo.html_url,
                            'updated_at': repo.updated_at.isoformat() if repo.updated_at else None
                        })
                    except Exception as e:
                        logger.error(f"Error fetching repo {repo_name}: {e}")
            
            return json_response({
                'repositories': repos,
                'total': len(repos)
            })
            
        except Exception as e:
            logger.error(f"Repository fetch error: {e}")
            return json_response({'error': str(e)}, status=500)

    async def chat_completion(self, request: Request) -> Response:
        """Chat completion using OpenAI"""
        try:
            data = await request.json()
            messages = data.get('messages', [])
            
            if not messages:
                return json_response({'error': 'Messages required'}, status=400)
            
            if not self.openai_client:
                return json_response({'error': 'OpenAI not configured'}, status=503)
            
            response = await asyncio.to_thread(
                openai.ChatCompletion.create,
                model=CONFIG['openai_model'],
                messages=messages,
                max_tokens=CONFIG['max_tokens'],
                temperature=CONFIG['temperature']
            )
            
            return json_response({
                'response': response.choices[0].message.content,
                'model': CONFIG['openai_model'],
                'usage': dict(response.usage) if hasattr(response, 'usage') else {}
            })
            
        except Exception as e:
            logger.error(f"Chat completion error: {e}")
            return json_response({'error': str(e)}, status=500)

    async def get_file_content(self, request: Request) -> Response:
        """Get file content from GitHub"""
        try:
            repo_name = request.query.get('repo')
            file_path = request.query.get('path')
            
            if not repo_name or not file_path:
                return json_response({'error': 'repo and path parameters required'}, status=400)
            
            if not self.github:
                return json_response({'error': 'GitHub not configured'}, status=503)
            
            repo = self.github.get_repo(repo_name)
            content = repo.get_contents(file_path)
            
            return json_response({
                'content': content.decoded_content.decode('utf-8'),
                'path': content.path,
                'name': content.name,
                'size': content.size,
                'url': content.html_url
            })
            
        except Exception as e:
            logger.error(f"File content error: {e}")
            return json_response({'error': str(e)}, status=500)

async def create_app():
    """Create and configure the web application"""
    backend = RealBackend()
    
    app = web.Application()
    
    # Setup CORS
    cors = cors_setup(app, defaults={
        "*": ResourceOptions(
            allow_credentials=True,
            expose_headers="*",
            allow_headers="*",
            allow_methods="*"
        )
    })
    
    # Routes
    app.router.add_get('/health', backend.health_check)
    app.router.add_post('/q', backend.search_code)
    app.router.add_get('/repos', backend.get_repositories)
    app.router.add_post('/chat', backend.chat_completion)
    app.router.add_get('/file', backend.get_file_content)
    
    # Add CORS to all routes
    for route in list(app.router.routes()):
        cors.add(route)
    
    return app

async def main():
    """Main function to run the server"""
    logger.info("🚀 Starting Real Backend Server...")
    
    # Validate configuration
    if not CONFIG['openai_api_key']:
        logger.warning("⚠️ OpenAI API key not found in environment")
    if not CONFIG['github_token']:
        logger.warning("⚠️ GitHub token not found in environment")
    
    app = await create_app()
    
    runner = web.AppRunner(app)
    await runner.setup()
    
    site = web.TCPSite(runner, CONFIG['host'], CONFIG['port'])
    await site.start()
    
    logger.info(f"✅ Real Backend running on http://{CONFIG['host']}:{CONFIG['port']}")
    logger.info("📋 Available endpoints:")
    logger.info("  - GET  /health - Health check")
    logger.info("  - POST /q - Search code")
    logger.info("  - GET  /repos - Get repositories")
    logger.info("  - POST /chat - Chat completion")
    logger.info("  - GET  /file - Get file content")
    
    # Keep the server running
    try:
        while True:
            await asyncio.sleep(1)
    except KeyboardInterrupt:
        logger.info("🛑 Shutting down server...")
        await runner.cleanup()

if __name__ == '__main__':
    asyncio.run(main())
