// =======================================
// 📄 FILE: html/js/template-manager.js
// 🔌 STEP: STEP 5 — TEMPLATE MANAGEMENT
// Fixed undefined functions and proper NUI communication
// VERSION: 1.0.0
// =======================================

class TemplateManager {
    constructor() {
        this.templates = [];
        this.selectedTemplate = null;
        this.currentGang = null;
        this.currentGrade = 0;
        this.isInitialized = false;
        
        this.init();
    }
    
    init() {
        try {
            this.setupEventListeners();
            this.isInitialized = true;
            console.log('[TemplateManager] Initialized successfully');
        } catch (error) {
            console.error('[TemplateManager] Initialization failed:', error);
        }
    }
    
    setupEventListeners() {
        // Template Filter Events
        const categoryFilters = document.querySelectorAll('.filter-btn');
        categoryFilters.forEach(btn => {
            btn.addEventListener('click', (e) => {
                const category = e.target.dataset.category;
                this.filterByCategory(category);
                
                // Update active filter
                categoryFilters.forEach(b => b.classList.remove('active'));
                e.target.classList.add('active');
            });
        });
        
        // Use Template Button
        const useTemplateBtn = document.getElementById('use-template-btn');
        if (useTemplateBtn) {
            useTemplateBtn.addEventListener('click', () => {
                this.useSelectedTemplate();
            });
        }
        
        // URL Preview Button
        const previewBtn = document.getElementById('preview-url-btn');
        if (previewBtn) {
            previewBtn.addEventListener('click', () => {
                this.previewUrl();
            });
        }
        
        // Search Input
        const searchInput = document.getElementById('template-search');
        if (searchInput) {
            searchInput.addEventListener('input', (e) => {
                this.searchTemplates(e.target.value);
            });
        }
    }
    
    loadTemplates(templates, gang, grade) {
        this.templates = templates || [];
        this.currentGang = gang;
        this.currentGrade = grade || 0;
        
        console.log('[TemplateManager] Templates loaded:', {
            count: this.templates.length,
            gang: this.currentGang,
            grade: this.currentGrade
        });
        
        this.renderTemplates();
    }
    
    renderTemplates(filteredTemplates = null) {
        const container = document.getElementById('template-grid');
        if (!container) {
            console.warn('[TemplateManager] Template grid container not found');
            return;
        }
        
        const templatesToRender = filteredTemplates || this.templates;
        container.innerHTML = '';
        
        if (templatesToRender.length === 0) {
            container.innerHTML = `
                <div class="no-templates">
                    <i class="fas fa-images"></i>
                    <p>Keine Templates verfügbar</p>
                </div>
            `;
            return;
        }
        
        templatesToRender.forEach(template => {
            const templateElement = this.createTemplateElement(template);
            container.appendChild(templateElement);
        });
    }
    
    createTemplateElement(template) {
        const element = document.createElement('div');
        element.className = 'template-item';
        element.dataset.templateId = template.id;
        element.dataset.category = template.category;
        
        const isAvailable = this.isTemplateAvailable(template);
        if (!isAvailable) {
            element.classList.add('locked');
        }
        
        element.innerHTML = `
            <div class="template-image">
                <img src="${this.getTemplateImageUrl(template)}" 
                     alt="${template.name}"
                     onerror="this.src='html/presets/default.png'">
                ${!isAvailable ? '<div class="template-lock"><i class="fas fa-lock"></i></div>' : ''}
            </div>
            <div class="template-name">${template.name}</div>
            <div class="template-category">${this.getCategoryDisplayName(template.category)}</div>
            ${template.requiredGrade > 0 ? `<div class="template-grade">Rang ${template.requiredGrade}+</div>` : ''}
        `;
        
        // Click Event
        if (isAvailable) {
            element.addEventListener('click', () => {
                this.selectTemplate(template);
            });
        } else {
            element.addEventListener('click', () => {
                this.showNotification(`Benötigt Gang-Rang ${template.requiredGrade} oder höher`, 'warning');
            });
        }
        
        return element;
    }
    
    getTemplateImageUrl(template) {
        // Versuche verschiedene URL-Formate
        const resourceName = this.getResourceName();
        const basePaths = [
            `nui://${resourceName}/${template.filePath}`,
            `nui://${resourceName}/html/presets/${template.id}.png`,
            `html/presets/${template.id}.png`,
            'html/presets/default.png' // Fallback
        ];
        
        return basePaths[0]; // Nutze ersten Pfad, Fallback wird im onerror gehandhabt
    }
    
    getResourceName() {
        try {
            return window.GetParentResourceName ? window.GetParentResourceName() : 'spray-system';
        } catch {
            return 'spray-system';
        }
    }
    
    isTemplateAvailable(template) {
        // Prüfe Gang-Berechtigung
        if (template.gang && template.gang !== this.currentGang) {
            return false;
        }
        
        // Prüfe Rang-Berechtigung
        if (template.requiredGrade && this.currentGrade < template.requiredGrade) {
            return false;
        }
        
        return true;
    }
    
    selectTemplate(template) {
        // Deselektiere vorherige Auswahl
        document.querySelectorAll('.template-item').forEach(item => {
            item.classList.remove('selected');
        });
        
        // Selektiere neues Template
        const element = document.querySelector(`[data-template-id="${template.id}"]`);
        if (element) {
            element.classList.add('selected');
        }
        
        this.selectedTemplate = template;
        
        // Enable Use Template Button
        const useBtn = document.getElementById('use-template-btn');
        if (useBtn) {
            useBtn.disabled = false;
            useBtn.innerHTML = `<i class="fas fa-check"></i> ${template.name} verwenden`;
        }
        
        console.log(`[TemplateManager] Template selected: ${template.id}`);
    }
    
    async useSelectedTemplate() {
        if (!this.selectedTemplate) {
            this.showNotification('Kein Template ausgewählt', 'warning');
            return;
        }
        
        try {
            // Sende Template-Auswahl an Lua
            const response = await this.sendToLua('useTemplate', {
                templateId: this.selectedTemplate.id,
                templateData: this.selectedTemplate,
                gang: this.currentGang
            });
            
            if (response && response.success) {
                this.showNotification(`Template "${this.selectedTemplate.name}" wird verwendet`, 'success');
                this.closeTemplateSelector();
            } else {
                throw new Error(response?.error || 'Fehler beim Verwenden des Templates');
            }
            
        } catch (error) {
            console.error('[TemplateManager] Use template error:', error);
            this.showError('Fehler beim Verwenden des Templates', error);
        }
    }
    
    filterByCategory(category) {
        let filteredTemplates;
        
        if (category === 'all') {
            filteredTemplates = this.templates;
        } else {
            filteredTemplates = this.templates.filter(template => 
                template.category === category
            );
        }
        
        this.renderTemplates(filteredTemplates);
    }
    
    searchTemplates(query) {
        if (!query.trim()) {
            this.renderTemplates();
            return;
        }
        
        const filteredTemplates = this.templates.filter(template =>
            template.name.toLowerCase().includes(query.toLowerCase()) ||
            template.category.toLowerCase().includes(query.toLowerCase())
        );
        
        this.renderTemplates(filteredTemplates);
    }
    
    getCategoryDisplayName(category) {
        const categoryNames = {
            gang: 'Gang',
            common: 'Allgemein',
            premium: 'Premium',
            custom: 'Custom'
        };
        
        return categoryNames[category] || category;
    }
    
    closeTemplateSelector() {
        const modal = document.getElementById('template-selector');
        if (modal) {
            modal.classList.add('hidden');
        }
        
        // Reset selection
        this.selectedTemplate = null;
        const useBtn = document.getElementById('use-template-btn');
        if (useBtn) {
            useBtn.disabled = true;
            useBtn.innerHTML = '<i class="fas fa-check"></i> Template verwenden';
        }
    }
    
    // URL Preview Functions
    async previewUrl() {
        const urlInput = document.getElementById('image-url');
        const url = urlInput?.value.trim();
        
        if (!url) {
            this.showNotification('Keine URL angegeben', 'warning');
            return;
        }
        
        if (!this.isValidImageUrl(url)) {
            this.showNotification('Ungültige Bild-URL', 'error');
            return;
        }
        
        try {
            // Zeige Loading
            const previewImg = document.getElementById('preview-image');
            const previewInfo = document.getElementById('preview-info');
            const useUrlBtn = document.getElementById('use-url-btn');
            
            if (previewImg) {
                previewImg.src = 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAiIGhlaWdodD0iNDAiIHZpZXdCb3g9IjAgMCA0MCA0MCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHBhdGggZD0iTTIwIDNDMTAuNjEgMyAzIDEwLjYxIDMgMjBTMTAuNjEgMzcgMjAgMzciIHN0cm9rZT0iIzMzNzNkYyIgc3Ryb2tlLXdpZHRoPSI0IiBzdHJva2UtbGluZWNhcD0icm91bmQiLz4KPC9zdmc+'; // Loading SVG
                previewImg.classList.remove('hidden');
            }
            
            // Lade Bild
            const img = new Image();
            img.crossOrigin = 'anonymous';
            
            img.onload = () => {
                if (previewImg) {
                    previewImg.src = url;
                }
                
                if (previewInfo) {
                    previewInfo.innerHTML = `
                        <div><strong>Größe:</strong> ${img.naturalWidth}x${img.naturalHeight}px</div>
                        <div><strong>URL:</strong> ${url.substring(0, 50)}${url.length > 50 ? '...' : ''}</div>
                    `;
                    previewInfo.classList.remove('hidden');
                }
                
                if (useUrlBtn) {
                    useUrlBtn.disabled = false;
                }
                
                this.showNotification('Bild-Vorschau geladen', 'success');
            };
            
            img.onerror = () => {
                throw new Error('Bild konnte nicht geladen werden');
            };
            
            img.src = url;
            
        } catch (error) {
            console.error('[TemplateManager] URL preview error:', error);
            this.showError('Fehler beim Laden der URL-Vorschau', error);
            
            // Reset Preview
            const previewImg = document.getElementById('preview-image');
            const previewInfo = document.getElementById('preview-info');
            const useUrlBtn = document.getElementById('use-url-btn');
            
            if (previewImg) previewImg.classList.add('hidden');
            if (previewInfo) previewInfo.classList.add('hidden');
            if (useUrlBtn) useUrlBtn.disabled = true;
        }
    }
    
    async useUrlImage() {
        const urlInput = document.getElementById('image-url');
        const url = urlInput?.value.trim();
        
        if (!url) {
            this.showNotification('Keine URL angegeben', 'warning');
            return;
        }
        
        try {
            // Sende URL an Lua
            const response = await this.sendToLua('useUrlImage', {
                imageUrl: url,
                gang: this.currentGang
            });
            
            if (response && response.success) {
                this.showNotification('URL-Bild wird verwendet', 'success');
                this.closeUrlInput();
            } else {
                throw new Error(response?.error || 'Fehler beim Verwenden der URL');
            }
            
        } catch (error) {
            console.error('[TemplateManager] Use URL error:', error);
            this.showError('Fehler beim Verwenden der URL', error);
        }
    }
    
    isValidImageUrl(url) {
        try {
            const urlObj = new URL(url);
            const validProtocols = ['http:', 'https:'];
            const validExtensions = ['.png', '.jpg', '.jpeg', '.gif', '.webp'];
            
            if (!validProtocols.includes(urlObj.protocol)) {
                return false;
            }
            
            const pathname = urlObj.pathname.toLowerCase();
            return validExtensions.some(ext => pathname.endsWith(ext)) || 
                   pathname.includes('image') || 
                   urlObj.hostname.includes('imgur') ||
                   urlObj.hostname.includes('discord');
        } catch {
            return false;
        }
    }
    
    closeUrlInput() {
        const modal = document.getElementById('url-input-modal');
        if (modal) {
            modal.classList.add('hidden');
        }
        
        // Reset form
        const urlInput = document.getElementById('image-url');
        const previewImg = document.getElementById('preview-image');
        const previewInfo = document.getElementById('preview-info');
        const useUrlBtn = document.getElementById('use-url-btn');
        
        if (urlInput) urlInput.value = '';
        if (previewImg) previewImg.classList.add('hidden');
        if (previewInfo) previewInfo.classList.add('hidden');
        if (useUrlBtn) useUrlBtn.disabled = true;
    }
    
    // Utility Functions
    showNotification(message, type = 'info') {
        const notification = document.getElementById('notification');
        const text = document.getElementById('notification-text');
        
        if (notification && text) {
            text.textContent = message;
            notification.className = `notification ${type}`;
            notification.classList.remove('hidden');
            
            // Auto-hide nach 3 Sekunden
            setTimeout(() => {
                notification.classList.add('hidden');
            }, 3000);
        }
    }
    
    showError(message, error = null) {
        const modal = document.getElementById('error-modal');
        const messageEl = document.getElementById('error-message');
        const stackEl = document.getElementById('error-stack');
        
        if (messageEl) messageEl.textContent = message;
        if (stackEl && error) {
            stackEl.textContent = error.stack || error.toString();
        }
        
        if (modal) modal.classList.remove('hidden');
        
        console.error('[TemplateManager] Error:', message, error);
    }
    
    async sendToLua(action, data) {
        try {
            const resourceName = this.getResourceName();
            
            const response = await fetch(`https://${resourceName}/${action}`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(data || {})
            });
            
            return await response.json();
        } catch (error) {
            console.error('[TemplateManager] Lua communication error:', error);
            return { success: false, error: error.message };
        }
    }
}

// Global Functions für HTML Events
function previewUrl() {
    if (window.templateManager) {
        window.templateManager.previewUrl();
    }
}

function useUrlImage() {
    if (window.templateManager) {
        window.templateManager.useUrlImage();
    }
}

function useSelectedTemplate() {
    if (window.templateManager) {
        window.templateManager.useSelectedTemplate();
    }
}

function closeTemplateSelector() {
    if (window.templateManager) {
        window.templateManager.closeTemplateSelector();
    }
}

function closeUrlInput() {
    if (window.templateManager) {
        window.templateManager.closeUrlInput();
    }
}

// NUI Message Handler für Template System
window.addEventListener('message', (event) => {
    const data = event.data;
    
    switch (data.type) {
        case 'openTemplateSelector':
            if (!window.templateManager) {
                window.templateManager = new TemplateManager();
            }
            
            document.getElementById('template-selector').classList.remove('hidden');
            window.templateManager.loadTemplates(data.templates, data.gang, data.grade);
            break;
            
        case 'openUrlInput':
            if (!window.templateManager) {
                window.templateManager = new TemplateManager();
            }
            
            window.templateManager.currentGang = data.gang;
            document.getElementById('url-input-modal').classList.remove('hidden');
            break;
            
        case 'closeTemplateSelector':
            if (window.templateManager) {
                window.templateManager.closeTemplateSelector();
            }
            break;
            
        case 'closeUrlInput':
            if (window.templateManager) {
                window.templateManager.closeUrlInput();
            }
            break;
    }
});

// Global Template Manager Instance erstellen
window.templateManager = new TemplateManager();

console.log('[TemplateManager] Script loaded successfully');