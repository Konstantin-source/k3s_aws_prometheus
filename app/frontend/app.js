// API URL: when accessed through Traefik, /api/v1 is routed to backend
const API_BASE = '/api/v1';

async function fetchInfo() {
  const start = performance.now();
  try {
    const res = await fetch(`${API_BASE}/info`);
    const latency = Math.round(performance.now() - start);
    document.getElementById('api-latency').innerText = `${latency} ms`;

    if (res.ok) {
      const data = await res.json();
      document.getElementById('pod-name').innerText = data.pod_name || 'Unbekannt';
      document.getElementById('node-name').innerText = data.node_name || 'AWS EC2 Node';
      document.getElementById('db-status').innerText = data.database_status || 'Verbunden';
    } else {
      document.getElementById('db-status').innerText = 'API-Fehler';
    }
  } catch (err) {
    console.error('Info fetch error:', err);
    document.getElementById('pod-name').innerText = 'Keine Verbindung';
    document.getElementById('node-name').innerText = 'Unbekannt';
    document.getElementById('db-status').innerText = 'Offline';
    document.getElementById('api-latency').innerText = '-- ms';
  }
}

async function fetchPosts() {
  const container = document.getElementById('posts-container');
  try {
    const res = await fetch(`${API_BASE}/posts`);
    if (res.ok) {
      const posts = await res.json();
      if (posts.length === 0) {
        container.innerHTML = '<p class="text-center text-slate-500 py-8">Noch keine Nachrichten vorhanden.</p>';
        return;
      }
      container.innerHTML = posts.map(p => `
        <div class="bg-slate-900/90 border border-slate-700/60 rounded-xl p-4 transition hover:border-slate-600">
          <div class="flex items-center justify-between mb-1.5">
            <h3 class="font-semibold text-slate-100 text-sm">${escapeHtml(p.title)}</h3>
            <span class="text-[10px] text-slate-400 font-mono">${p.created_at ? new Date(p.created_at).toLocaleTimeString() : ''}</span>
          </div>
          <p class="text-slate-300 text-xs mb-2 leading-relaxed">${escapeHtml(p.content)}</p>
          <div class="flex items-center justify-between text-[11px] text-slate-400 pt-2 border-t border-slate-800">
            <span class="flex items-center"><i class="fa-solid fa-user-circle mr-1 text-indigo-400"></i> ${escapeHtml(p.author || 'Anonym')}</span>
            <span class="text-[10px] text-slate-500">ID: #${p.id}</span>
          </div>
        </div>
      `).join('');
    }
  } catch (err) {
    container.innerHTML = '<p class="text-center text-red-400 py-8">Fehler beim Abrufen der Nachrichten.</p>';
  }
}

document.getElementById('post-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const title = document.getElementById('post-title').value.trim();
  const author = document.getElementById('post-author').value.trim();
  const content = document.getElementById('post-content').value.trim();

  if (!title || !content) return;

  try {
    const res = await fetch(`${API_BASE}/posts`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ title, author, content })
    });
    if (res.ok) {
      document.getElementById('post-title').value = '';
      document.getElementById('post-content').value = '';
      await fetchPosts();
      await fetchInfo();
    }
  } catch (err) {
    alert('Fehler beim Speichern: ' + err.message);
  }
});

document.getElementById('trigger-load-btn').addEventListener('click', async () => {
  const btn = document.getElementById('trigger-load-btn');
  const resultDiv = document.getElementById('load-result');
  btn.disabled = true;
  btn.innerHTML = '<i class="fa-solid fa-spinner animate-spin"></i><span>Berechne Last...</span>';
  resultDiv.classList.remove('hidden');
  resultDiv.innerText = 'Rechenintensiver Request an Backend gesendet...';

  try {
    const res = await fetch(`${API_BASE}/work?iterations=750000`);
    if (res.ok) {
      const data = await res.json();
      resultDiv.innerHTML = `✅ Last erzeugt in ${data.duration_seconds}s auf Pod <span class="text-indigo-300">${data.handled_by_pod}</span>`;
    }
  } catch (err) {
    resultDiv.innerText = 'Fehler beim Lasttest: ' + err.message;
  } finally {
    btn.disabled = false;
    btn.innerHTML = '<i class="fa-solid fa-microchip"></i><span>CPU-Last anfordern (500k Ops)</span>';
  }
});

document.getElementById('refresh-btn').addEventListener('click', () => {
  fetchInfo();
  fetchPosts();
});

function escapeHtml(text) {
  if (!text) return '';
  return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

// Initial polling
fetchInfo();
fetchPosts();
setInterval(fetchInfo, 5000);
