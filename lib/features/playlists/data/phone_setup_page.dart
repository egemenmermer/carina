/// The single self-contained mobile page that "Add from phone" serves: inline
/// HTML, CSS and JS, Carina's dark style, texts in the TV app's language.
library;

import 'dart:convert';

import 'package:carina/l10n/gen/app_localizations.dart';

/// Every text of the page, in the language of [l10n]. The `e_*` keys are the
/// messages of the wizard's validation problems (`WizardProblem.name`).
Map<String, String> phoneSetupStrings(L10n l10n) => {
  'title': l10n.playlistsPhonePageTitle,
  'intro': l10n.playlistsPhonePageIntro,
  'xtream': l10n.playlistsPhonePageXtream,
  'm3u': l10n.playlistsPhonePageM3u,
  'name': l10n.playlistsPhonePageName,
  'server': l10n.playlistsFieldServer,
  'username': l10n.playlistsFieldUsername,
  'password': l10n.playlistsFieldPassword,
  'playlistUrl': l10n.playlistsFieldPlaylistUrl,
  'epgUrl': l10n.playlistsPhonePageEpg,
  'show': l10n.playlistsPhonePageShow,
  'hide': l10n.playlistsPhonePageHide,
  'send': l10n.playlistsPhonePageSend,
  'sending': l10n.playlistsPhonePageSending,
  'doneTitle': l10n.playlistsPhonePageDoneTitle,
  'doneBody': l10n.playlistsPhonePageDoneBody,
  'gone': l10n.playlistsPhonePageGone,
  'network': l10n.playlistsPhonePageNetwork,
  'check': l10n.playlistsPhonePageCheck,
  'e_name': l10n.playlistsErrorName,
  'e_serverEmpty': l10n.playlistsErrorServer,
  'e_serverScheme': l10n.playlistsErrorServerScheme,
  'e_serverPort': l10n.playlistsErrorServerPort,
  'e_serverInvalid': l10n.playlistsErrorServerInvalid,
  'e_username': l10n.playlistsErrorUsername,
  'e_password': l10n.playlistsErrorPassword,
  'e_urlEmpty': l10n.playlistsErrorUrl,
  'e_urlInvalid': l10n.playlistsErrorUrlInvalid,
  'e_epgInvalid': l10n.playlistsErrorEpgInvalid,
};

/// JSON that is safe inside a `<script>` element.
String _scriptJson(Object value) => jsonEncode(value)
    .replaceAll('<', r'\u003c')
    .replaceAll('>', r'\u003e')
    .replaceAll('&', r'\u0026')
    .replaceAll('\u2028', r'\u2028')
    .replaceAll('\u2029', r'\u2029');

/// The page for a phone whose app language is [lang] (`en`, `tr`).
String buildPhoneSetupPage({
  required String lang,
  required Map<String, String> strings,
}) {
  final safeLang = RegExp(r'^[a-z]{2,3}$').hasMatch(lang) ? lang : 'en';
  return _template
      .replaceFirst('{{LANG}}', safeLang)
      .replaceFirst('{{STRINGS}}', _scriptJson(strings));
}

const String _template = r'''<!doctype html>
<html lang="{{LANG}}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="color-scheme" content="dark">
<meta name="theme-color" content="#000000">
<meta name="referrer" content="no-referrer">
<title>Carina</title>
<style>
:root{--bg:#000;--surface:#1c1c1e;--field:#262626;--stroke:#3a3a3c;--text:#fff;--muted:#a9a9a9;--accent:#ff2500;--accent-hover:#ff4524;--ok:#1fa344}
*{box-sizing:border-box;-webkit-tap-highlight-color:transparent}
html{background:var(--bg)}
body{margin:0;min-height:100vh;min-height:100dvh;background:var(--bg);color:var(--text);font:16px/1.45 Inter,-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,system-ui,sans-serif;-webkit-font-smoothing:antialiased}
main{max-width:480px;margin:0 auto;padding:max(28px,env(safe-area-inset-top)) 20px max(32px,env(safe-area-inset-bottom))}
.brand{font-size:13px;font-weight:700;letter-spacing:.32em;color:var(--accent);margin:0 0 28px}
h1{font-size:26px;line-height:1.2;font-weight:700;letter-spacing:-.01em;margin:0 0 8px}
.intro{margin:0 0 24px;color:var(--muted);font-size:15px}
.seg{display:grid;grid-template-columns:1fr 1fr;gap:4px;padding:4px;margin:0 0 22px;background:var(--surface);border-radius:999px}
.seg button{appearance:none;border:0;border-radius:999px;padding:12px 8px;background:transparent;color:var(--muted);font:inherit;font-weight:600;cursor:pointer}
.seg button[aria-selected=true]{background:#f5f5f5;color:#000}
.field{margin:0 0 14px}
.field[hidden]{display:none}
.box{position:relative}
input{display:block;width:100%;height:54px;padding:0 16px;border:1.5px solid transparent;border-radius:14px;background:var(--field);color:var(--text);font:inherit;font-size:16px;outline:none;transition:border-color .15s}
input::placeholder{color:#7a7a7e}
input:focus{border-color:var(--stroke)}
input.bad{border-color:var(--accent)}
.box input.pw{padding-right:76px}
.toggle{position:absolute;right:6px;top:6px;height:42px;padding:0 12px;border:0;border-radius:10px;background:transparent;color:var(--muted);font:inherit;font-size:14px;font-weight:600;cursor:pointer}
.err{min-height:0;margin:6px 4px 0;color:#ff6b57;font-size:13px}
.err:empty{display:none}
.send{appearance:none;display:block;width:100%;height:56px;margin-top:22px;border:0;border-radius:999px;background:var(--accent);color:#fff;font:inherit;font-size:17px;font-weight:700;cursor:pointer;transition:background .15s,opacity .15s}
.send:active{background:#d81f00}
.send:disabled{opacity:.6}
.banner{margin:18px 0 0;padding:12px 16px;border-radius:14px;background:var(--surface);color:#ff8a78;font-size:14px}
.banner:empty{display:none}
.done{text-align:center;padding-top:12vh}
.done .tick{width:64px;height:64px;margin:0 auto 22px;border-radius:50%;background:var(--ok);display:grid;place-items:center}
.done .tick svg{width:30px;height:30px}
.done p{margin:10px 0 0;color:var(--muted)}
[hidden]{display:none!important}
</style>
</head>
<body>
<main>
<div id="form">
<p class="brand">CARINA</p>
<h1 data-s="title"></h1>
<p class="intro" data-s="intro"></p>
<div class="seg" role="tablist">
<button type="button" role="tab" data-type="xtream" aria-selected="true" data-s="xtream"></button>
<button type="button" role="tab" data-type="m3u" aria-selected="false" data-s="m3u"></button>
</div>
<form id="f" novalidate autocomplete="off">
<div class="field"><input name="name" data-ph="name" autocapitalize="words" autocomplete="off" spellcheck="false"><div class="err" data-err="name"></div></div>
<div class="field" data-for="xtream"><input name="server" data-ph="server" type="url" inputmode="url" autocapitalize="off" autocorrect="off" autocomplete="off" spellcheck="false"><div class="err" data-err="server"></div></div>
<div class="field" data-for="xtream"><input name="username" data-ph="username" autocapitalize="off" autocorrect="off" autocomplete="off" spellcheck="false"><div class="err" data-err="username"></div></div>
<div class="field" data-for="xtream"><div class="box"><input class="pw" name="password" data-ph="password" type="password" autocapitalize="off" autocorrect="off" autocomplete="new-password" spellcheck="false"><button type="button" class="toggle" id="pw-toggle"></button></div><div class="err" data-err="password"></div></div>
<div class="field" data-for="m3u" hidden><input name="playlistUrl" data-ph="playlistUrl" type="url" inputmode="url" autocapitalize="off" autocorrect="off" autocomplete="off" spellcheck="false"><div class="err" data-err="playlistUrl"></div></div>
<div class="field"><input name="epgUrl" data-ph="epgUrl" type="url" inputmode="url" autocapitalize="off" autocorrect="off" autocomplete="off" spellcheck="false"><div class="err" data-err="epgUrl"></div></div>
<div class="banner" id="banner" role="alert"></div>
<button class="send" id="send" type="submit"></button>
</form>
</div>
<div class="done" id="done" hidden>
<div class="tick"><svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg></div>
<h1 data-s="doneTitle"></h1>
<p data-s="doneBody"></p>
</div>
</main>
<script type="application/json" id="strings">{{STRINGS}}</script>
<script>
(function(){
var S=JSON.parse(document.getElementById('strings').textContent);
var $=function(q,r){return (r||document).querySelector(q)};
var $$=function(q,r){return Array.prototype.slice.call((r||document).querySelectorAll(q))};
$$('[data-s]').forEach(function(e){e.textContent=S[e.getAttribute('data-s')]});
$$('[data-ph]').forEach(function(e){e.placeholder=S[e.getAttribute('data-ph')]});
document.title='Carina - '+S.title;
var form=$('#f'),banner=$('#banner'),send=$('#send'),pw=$('input[name=password]'),tog=$('#pw-toggle');
var type='xtream';
send.textContent=S.send;
tog.textContent=S.show;
tog.onclick=function(){var show=pw.type==='password';pw.type=show?'text':'password';tog.textContent=show?S.hide:S.show};
function setType(t){
  type=t;
  $$('.seg button').forEach(function(b){b.setAttribute('aria-selected',String(b.getAttribute('data-type')===t))});
  $$('[data-for]').forEach(function(f){f.hidden=f.getAttribute('data-for')!==t});
  clearErrors();
}
$$('.seg button').forEach(function(b){b.onclick=function(){setType(b.getAttribute('data-type'))}});
function clearErrors(){
  banner.textContent='';
  $$('.err').forEach(function(e){e.textContent=''});
  $$('input.bad').forEach(function(i){i.classList.remove('bad')});
}
function field(n){return form.elements[n]}
function showErrors(errors){
  var first=null;
  Object.keys(errors).forEach(function(k){
    var slot=$('[data-err='+k+']'),input=field(k);
    if(slot)slot.textContent=S['e_'+errors[k]]||'';
    if(input){input.classList.add('bad');if(!first)first=input}
  });
  banner.textContent=S.check;
  if(first)first.focus({preventScroll:false});
}
form.addEventListener('submit',function(ev){
  ev.preventDefault();
  clearErrors();
  var body={type:type,name:field('name').value,epgUrl:field('epgUrl').value};
  if(type==='xtream'){body.server=field('server').value;body.username=field('username').value;body.password=field('password').value}
  else{body.playlistUrl=field('playlistUrl').value}
  send.disabled=true;send.textContent=S.sending;
  fetch(location.pathname,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body),credentials:'omit',referrerPolicy:'no-referrer'})
    .then(function(r){return r.json().catch(function(){return {}}).then(function(j){return {s:r.status,j:j}})})
    .then(function(r){
      if(r.s===200){$('#form').hidden=true;$('#done').hidden=false;window.scrollTo(0,0);return}
      send.disabled=false;send.textContent=S.send;
      if(r.s===422&&r.j&&r.j.errors){showErrors(r.j.errors);return}
      banner.textContent=(r.s===404||r.s===410)?S.gone:S.network;
    })
    .catch(function(){send.disabled=false;send.textContent=S.send;banner.textContent=S.network});
});
})();
</script>
</body>
</html>
''';
