#!/usr/bin/env node
/**
 * Mock Backend Server for Bloop
 * Provides realistic API responses for testing
 */

const express = require('express');
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = process.env.BLOOP_BACKEND_PORT || 7878;
const HOST = process.env.BLOOP_HOST || '127.0.0.1';

// Middleware
app.use(cors());
app.use(express.json());

// Logging middleware
app.use((req, res, next) => {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
    next();
});

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        service: 'bloop-mock-backend',
        version: '1.0.0',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        features: {
            openai_enabled: true,
            github_enabled: true
        }
    });
});

// Mock search endpoint
app.post('/q', (req, res) => {
    const { q: query, repos, lang } = req.body;
    
    // Simulate search delay
    setTimeout(() => {
        res.json({
            query: query || '',
            results: [
                {
                    file: 'src/main.js',
                    repo: 'bloop',
                    line: 42,
                    content: `function searchCode(query) {\n  // Mock search result for: ${query}\n  return results;\n}`,
                    score: 0.95,
                    highlights: [
                        { start: 15, end: 25, type: 'match' }
                    ]
                },
                {
                    file: 'lib/utils.py',
                    repo: 'bloop',
                    line: 128,
                    content: `def process_query(q):\n    """Process search query: ${query}"""\n    return filtered_results`,
                    score: 0.87,
                    highlights: [
                        { start: 35, end: 45, type: 'match' }
                    ]
                },
                {
                    file: 'README.md',
                    repo: 'bloop',
                    line: 1,
                    content: `# Bloop Code Search\n\nSearch your codebase with: ${query}`,
                    score: 0.72,
                    highlights: [
                        { start: 45, end: 55, type: 'match' }
                    ]
                }
            ],
            stats: {
                total_results: 3,
                search_time_ms: 150,
                repos_searched: repos ? repos.length : 1,
                files_searched: 1247
            }
        });
    }, 100);
});

// Mock repository list endpoint
app.get('/repos', (req, res) => {
    res.json({
        repositories: [
            {
                name: 'bloop',
                path: '/path/to/bloop',
                indexed: true,
                last_indexed: new Date().toISOString(),
                files_count: 1247,
                size_bytes: 15728640,
                languages: ['JavaScript', 'Python', 'Rust', 'TypeScript']
            },
            {
                name: 'example-repo',
                path: '/path/to/example',
                indexed: true,
                last_indexed: new Date(Date.now() - 3600000).toISOString(),
                files_count: 523,
                size_bytes: 8421376,
                languages: ['Python', 'JavaScript']
            }
        ]
    });
});

// Mock file content endpoint
app.get('/file/:repo/:filename', (req, res) => {
    const repo = req.params.repo;
    const filePath = req.params.filename;
    
    res.json({
        repo: repo,
        path: filePath,
        content: `// Mock content for ${filePath}\n// This is a simulated file from ${repo}\n\nfunction mockFunction() {\n    console.log('This is mock content');\n    return 'success';\n}\n\nexport default mockFunction;`,
        language: 'javascript',
        size: 256,
        last_modified: new Date().toISOString()
    });
});

// Mock AI chat endpoint (if OpenAI is enabled)
app.post('/chat', (req, res) => {
    const { message, context } = req.body;
    
    setTimeout(() => {
        res.json({
            response: `This is a mock AI response to: "${message}". In a real deployment, this would use OpenAI's API to provide intelligent code analysis and explanations.`,
            context_used: context ? context.length : 0,
            model: 'mock-gpt-4',
            timestamp: new Date().toISOString()
        });
    }, 500);
});

// Mock indexing status endpoint
app.get('/index/status', (req, res) => {
    res.json({
        status: 'completed',
        progress: 100,
        indexed_files: 1247,
        total_files: 1247,
        last_update: new Date().toISOString(),
        indexing_time_ms: 45000
    });
});

// Mock configuration endpoint
app.get('/config', (req, res) => {
    res.json({
        host: HOST,
        port: PORT,
        features: {
            ai_enabled: true,
            github_integration: true,
            real_time_indexing: true
        },
        version: '1.0.0-mock'
    });
});

// Error handling
app.use((err, req, res, next) => {
    console.error('Error:', err);
    res.status(500).json({
        error: 'Internal server error',
        message: err.message,
        timestamp: new Date().toISOString()
    });
});

// 404 handler
app.use((req, res) => {
    res.status(404).json({
        error: 'Not found',
        path: req.path,
        method: req.method,
        timestamp: new Date().toISOString()
    });
});

// Start server
app.listen(PORT, HOST, () => {
    console.log(`🚀 Mock Bloop Backend running on http://${HOST}:${PORT}`);
    console.log(`📊 Health check: http://${HOST}:${PORT}/health`);
    console.log(`🔍 Search endpoint: POST http://${HOST}:${PORT}/q`);
    console.log(`📁 Repositories: GET http://${HOST}:${PORT}/repos`);
    console.log('🎭 Mock mode - providing realistic API responses for testing');
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('🛑 Received SIGTERM, shutting down gracefully');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('🛑 Received SIGINT, shutting down gracefully');
    process.exit(0);
});
