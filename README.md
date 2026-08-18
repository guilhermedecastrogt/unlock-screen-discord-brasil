# screen-discord-brasil

Prova de conceito (PoC) que demonstra que o bloqueio de **compartilhamento de tela / vídeo** aplicado pelo Discord a contas brasileiras é validado **no client-side**, e não no servidor.

O script abaixo cria um *override* local do experimento `2026-08-video-guard` — o mesmo mecanismo que o próprio client do Discord usa para decidir se a feature fica ligada ou desligada — e reabilita o recurso sem tocar em nada do lado do servidor.

> **Resumo técnico:** se um flag de experimento entregue ao client é suficiente para reverter a restrição, a restrição não é um controle de segurança. É apenas UI.

---

## ⚠️ Aviso

Este repositório existe para fins **educacionais e de pesquisa em segurança**, para documentar onde a validação acontece.

- Rodar client mods e alterar o client do Discord **viola os Termos de Serviço** do Discord e pode resultar em suspensão da conta.
- Use por sua conta e risco, apenas na sua própria conta.
- O autor não se responsabiliza por qualquer consequência do uso.

---

## Pré-requisitos

| Item | Detalhe |
|---|---|
| **Discord Desktop** | O client instalado (não a versão do navegador, a não ser que use a extensão do Vencord) |
| **[Vencord](https://vencord.dev/)** | Necessário — ele expõe o objeto global `Vencord` com acesso ao Webpack interno do Discord |
| **Conta brasileira** | Uma conta que já esteja com o bloqueio de tela/vídeo ativo (senão não há o que testar) |

### Instalando o Vencord

1. Baixe o instalador oficial: **https://vencord.dev/download**
2. Feche o Discord completamente (verifique a bandeja do sistema / `Cmd+Q` no macOS).
3. Rode o instalador → **Install Vencord** → selecione a sua instalação do Discord (Stable / PTB / Canary).
4. Abra o Discord novamente. Se aparecer a aba **Vencord** em *Configurações do Usuário*, está instalado.

> Nunca instale client mods de fontes que não sejam o site oficial do Vencord.

---

## Como testar

### 1. Confirme que o bloqueio está ativo

Antes de rodar qualquer coisa, entre em um canal de voz e tente iniciar o compartilhamento de tela / câmera.
Você deve ver o bloqueio (botão desabilitado, aviso de restrição regional, etc.). **Tire um print** — é a sua evidência do "antes".

### 2. Abra o DevTools

Com o Vencord instalado, o DevTools do Electron fica liberado:

| Sistema | Atalho |
|---|---|
| Windows / Linux | `Ctrl` + `Shift` + `I` |
| macOS | `Cmd` + `Option` + `I` |

Se o atalho não funcionar, vá em **Configurações → Vencord → Enable React DevTools / Open DevTools**, ou rode o Discord com a flag `--remote-debugging-port=9222`.

Vá até a aba **Console**.

### 3. Libere o paste no console

O Chrome/Electron bloqueia colar no console na primeira vez por segurança (proteção contra self-XSS). Ele vai pedir para você digitar:

```
allow pasting
```

Digite isso, dê `Enter`, e depois cole o script.

### 4. Cole o script

Copie todo o conteúdo de [`script.js`](script.js) e cole no console:

```js
(() => {
    if (!Object.values(Vencord.Webpack.wreq(Vencord.Webpack.findModuleId("2026-08-video-guard"))).find(
        x => x?.definition?.name === "2026-08-video-guard"
    ))
        throw new Error("not found");

    Vencord.Webpack.Common.FluxDispatcher.dispatch({
        type: "APEX_EXPERIMENT_SESSION_OVERRIDE_CREATE",
        experimentName: "2026-08-video-guard",
        variantId: 0
    });

    console.log("enabled!");
})();
```

Pressione `Enter`.

### 5. Resultado esperado

```
enabled!
```

Se aparecer `enabled!`, o override foi aplicado. Volte para o canal de voz e tente compartilhar a tela / ligar a câmera novamente.

**Funcionou = o bloqueio era client-side.** Nenhuma requisição foi feita, nenhum header foi alterado, nenhum endpoint foi burlado — só um flag local.

---

## Como o script funciona

```js
Vencord.Webpack.findModuleId("2026-08-video-guard")
```
Varre o bundle Webpack do Discord procurando o módulo cujo código-fonte contém a string `2026-08-video-guard`. **Ponto-chave:** a definição do experimento está *dentro do JavaScript entregue ao seu navegador*.

```js
Vencord.Webpack.wreq(id)
```
`wreq` é o `__webpack_require__` interno. Carrega o módulo encontrado e devolve seus exports.

```js
Object.values(...).find(x => x?.definition?.name === "2026-08-video-guard")
```
Procura entre os exports o objeto de definição do experimento. Se não achar, o script joga `not found` — isso significa que o nome do experimento mudou (ver [Troubleshooting](#troubleshooting)).

```js
Vencord.Webpack.Common.FluxDispatcher.dispatch({
    type: "APEX_EXPERIMENT_SESSION_OVERRIDE_CREATE",
    experimentName: "2026-08-video-guard",
    variantId: 0
});
```
Dispara uma action na store Flux do próprio Discord. `APEX_EXPERIMENT_SESSION_OVERRIDE_CREATE` é o mecanismo **nativo** de override de experimentos (o mesmo usado pelo painel interno de staff). `variantId: 0` é o bucket de controle — ou seja, "feature desligada", que no caso do *video guard* significa **sem bloqueio**.

Não há patch, não há hook, não há monkey-patching. O script apenas usa a API que já existe no client.

---

## Como reverter

O override é **por sessão** e não é persistido. Basta:

- `Ctrl` + `R` (recarregar o client), **ou**
- fechar e abrir o Discord, **ou**
- disparar o inverso no console:

```js
Vencord.Webpack.Common.FluxDispatcher.dispatch({
    type: "APEX_EXPERIMENT_SESSION_OVERRIDE_DELETE",
    experimentName: "2026-08-video-guard"
});
```

---

## Troubleshooting

| Erro / sintoma | Causa provável | Solução |
|---|---|---|
| `Vencord is not defined` | Vencord não instalado, ou você está no console do navegador sem a extensão | Instale o Vencord e reinicie o Discord |
| `Uncaught Error: not found` | O nome do experimento mudou (ex.: `2026-09-...`) | Ver "Descobrindo o novo nome" abaixo |
| Colar não funciona | Proteção contra self-XSS | Digite `allow pasting` no console primeiro |
| Rodou `enabled!` mas o botão continua bloqueado | O componente já foi montado com o valor antigo | `Ctrl+R` **não** — isso limpa o override. Saia e entre no canal de voz de novo |
| Atalho do DevTools não abre | Build do Discord sem DevTools liberado | Configurações → Vencord → *Open DevTools* |

### Descobrindo o novo nome do experimento

Se o Discord renomear o experimento, ache a nova string no console:

```js
// lista todos os experimentos carregados no client
Object.keys(Vencord.Webpack.Common.FluxDispatcher._actionHandlers._dependencyGraph.nodes)
```

Ou, mais direto — procure por padrões de data no bundle:

```js
Vencord.Webpack.findAll?.(m => JSON.stringify(m)?.includes("video-guard"))
```

Depois é só trocar as duas ocorrências de `2026-08-video-guard` no script.

---

## Por que isso importa

Restrições regionais implementadas como *feature flags* do client são **cosméticas**. Elas informam a UI, não protegem nada:

1. A definição do experimento é enviada para o client.
2. O client decide sozinho se mostra ou não a feature.
3. O mecanismo de override é parte do próprio client.

Um controle real precisaria ser aplicado no servidor de voz/mídia — recusando a stream no momento em que ela é publicada, não escondendo o botão. Enquanto a decisão morrer no client, qualquer pessoa com o DevTools aberto reverte em uma linha.

---

## Licença

MIT — veja [LICENSE](LICENSE).
