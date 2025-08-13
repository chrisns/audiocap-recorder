(function(){
  async function loadVersions(){
    try{
      const baseUrl =
        (window.__docusaurus && window.__docusaurus.baseUrl) || "/";
      const res = await fetch(baseUrl.replace(/\/$/, "") + "/versions.json");
      if(!res.ok) return;
      const versions = await res.json();
      const el = document.getElementById('version-switcher');
      if(!el) return;
      const select = document.createElement('select');
      select.style.padding = '4px 8px';
      const current = window.location.pathname;
      const options = versions.map(v=>({label: v.version || 'latest', url: v.url, latest: !!v.latest}));
      for(const opt of options){
        const o = document.createElement('option');
        o.value = opt.url;
        o.textContent = opt.latest && !opt.label ? 'latest' : opt.label + (opt.latest ? ' (latest)' : '');
        try {
          const u = new URL(opt.url, window.location.href);
          if (current.startsWith(u.pathname)) o.selected = true;
        } catch {
          if (current.startsWith(opt.url)) o.selected = true;
        }
        select.appendChild(o);
      }
      select.addEventListener('change', ()=>{
        const u = select.value;
        try {
          window.location.href = new URL(u, window.location.href).href;
        } catch {
          window.location.href = u;
        }
      });
      el.innerHTML = '';
      el.appendChild(select);
    }catch(e){
      // ignore
    }
  }
  if(document.readyState === 'loading') document.addEventListener('DOMContentLoaded', loadVersions);
  else loadVersions();
})();
