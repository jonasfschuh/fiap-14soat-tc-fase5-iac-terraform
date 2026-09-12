# ADR-003 — NGINX Ingress Controller como Único Ponto de Entrada do Cluster Kubernetes Local

| Campo        | Valor                                                                   |
|--------------|-------------------------------------------------------------------------|
| **ADR**      | 003                                                                     |
| **Título**   | Ingress NGINX (Helm) como porta de entrada HTTP do cluster Kubernetes local |
| **Repositório** | fiap-14soat-tc-fase5-iac-terraform                                     |
| **Status**   | Aceito — **revisado em 2026-09-10** (substitui a versão anterior baseada em NLB + VPC Link da AWS) |
| **Data**     | 2026-04-20 (criado) · 2026-09-10 (revisado — remoção de toda dependência AWS) |
| **Decisores**| Time FIAP 14SOAT Fase 5                                                 |

---

## ⚠️ Nota sobre a revisão

A versão original deste ADR descrevia um **NLB interno + VPC Link conectado a um AWS API Gateway**, dando acesso a um cluster **EKS**. Essa arquitetura **não existe mais no projeto**: não há conta AWS, VPC, API Gateway, NLB ou EKS envolvidos. O `provider.tf` deste repositório usa exclusivamente o **kubeconfig local, apontando para o contexto do Kubernetes do Docker Desktop** (`config_path = "~/.kube/config"`). Esta revisão substitui a decisão por aquela efetivamente implementada em `infra/ingress.tf`.

---

## Contexto

Após provisionar o **namespace `fiapx` em um cluster Kubernetes local (Docker Desktop)**, a equipe precisou definir como as requisições HTTP externas (do navegador/Postman/testes locais) chegariam aos Services dos microsserviços (`auth`, `video-upload`, `video-processing`, `video-status`, `video-download`, `notification`). As opções avaliadas foram:

1. **NGINX Ingress Controller** (Helm chart oficial `ingress-nginx`), roteando por path para cada Service;
2. `NodePort` direto por serviço, exigindo memorizar uma porta distinta por microsserviço;
3. `LoadBalancer` Service individual por microsserviço (sem roteamento por path, um IP/porta externo por serviço).

---

## Decisão

**Instalar o `ingress-nginx` via Helm (`helm_release.ingress_nginx`)**, com `service.type = LoadBalancer` (resolvido localmente pelo Docker Desktop), e definir um único recurso `kubernetes_ingress_v1.fiapx` com roteamento por prefixo de path para cada microsserviço:

| Path | Service | Porta |
|---|---|---|
| `/auth` | `auth-service` | 8090 |
| `/video-upload` | `video-upload-service` | 8083 |
| `/processing` | `video-processing-service` | 8086 |
| `/status` | `video-status-service` | 8084 |
| `/download` | `video-download-service` | 8085 |
| `/notify` | `notification-service` | 8087 |

O Ingress usa `nginx.ingress.kubernetes.io/rewrite-target` + `use-regex` para reescrever o path antes de encaminhar ao Service, e configura `proxy-body-size: 500m` (uploads de vídeo) e timeouts de 300s (`proxy-read-timeout`/`proxy-send-timeout`) para suportar arquivos grandes.

---

## Justificativa

| Critério | NGINX Ingress (escolhido) | NodePort direto | LoadBalancer por serviço |
|----------|----------------------------|------------------|---------------------------|
| Ponto único de entrada | Sim — 1 IP/porta para todos os serviços | Não — 1 porta por serviço | Não — 1 IP por serviço |
| Roteamento por path | Sim (`/auth`, `/status`, etc.) | Não | Não |
| Configuração de limites (upload, timeout) | Centralizada em anotações do Ingress | Por serviço, sem padronização | Por serviço, sem padronização |
| Custo/complexidade no Docker Desktop | Baixa — Helm chart padrão da comunidade | Baixa, mas sem organização | Múltiplos LoadBalancers locais (`localhost` só resolve 1 por vez de forma simples) |
| Alinhamento com práticas de mercado | Sim — Ingress é o padrão de-facto em Kubernetes | Não recomendado para produção | Válido, mas sem roteamento HTTP inteligente |

O **NGINX Ingress** foi escolhido porque:
- É o controlador de Ingress mais adotado no ecossistema Kubernetes, com Helm chart oficial mantido pela comunidade;
- Permite expor todos os microsserviços atrás de um único endereço local, roteando por prefixo de path;
- Suporta anotações para ajustar limites de payload (essencial para upload de vídeos) sem precisar de configuração por serviço;
- Não depende de nenhum recurso específico de nuvem — funciona da mesma forma em qualquer cluster Kubernetes (Docker Desktop, kind, minikube, EKS, etc.), o que facilita portar a solução no futuro caso a equipe volte a ter acesso a uma conta AWS.

---

## Consequências

### Positivas
- **Zero dependência de AWS** — toda a infraestrutura roda localmente via Docker Desktop + Terraform;
- Um único ponto de entrada HTTP simplifica testes manuais e a apresentação da solução;
- Configuração de upload de arquivos grandes (500MB) centralizada em anotações do Ingress;
- Arquitetura portável — o mesmo Ingress funcionaria em um cluster gerenciado na nuvem, se necessário no futuro.

### Negativas / Riscos
- Sem WAF, autenticação de borda ou rate limiting adicional — a proteção depende inteiramente da aplicação (`auth`-service com JWT, ver ADR-001 do repositório `auth`);
- `service.type = LoadBalancer` no Docker Desktop depende do balanceador de carga interno do Docker Desktop (não é um LoadBalancer gerenciado de nuvem) — não reflete o comportamento de um ambiente de produção real;
- Se o Ingress Controller cair, todos os microsserviços ficam inacessíveis externamente (ponto único de falha para tráfego HTTP externo).

---

## Alternativas Consideradas

### NodePort direto por serviço
- Simples de configurar, mas exige lembrar uma porta por serviço e não oferece roteamento por path;
- Sem suporte nativo a limites de payload/timeout centralizados.

### LoadBalancer Service individual por microsserviço
- Cada serviço ganharia seu próprio IP/porta local — mais difícil de organizar e apresentar;
- Sem roteamento HTTP inteligente (path-based), apenas encaminhamento de camada 4.

### AWS API Gateway + NLB + VPC Link (arquitetura original, revogada)
- Adequada apenas com conta AWS ativa (cenário de uma fase anterior do curso);
- Sem essa infraestrutura disponível, foi substituída pelo Ingress NGINX local.

---

## Notas de Implementação

```hcl
# infra/ingress.tf
resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = kubernetes_namespace_v1.fiapx.metadata[0].name

  values = [yamlencode({
    controller = {
      ingressClassResource = { name = "nginx", enabled = true, default = true }
      service              = { type = "LoadBalancer" }
    }
  })]
}

resource "kubernetes_ingress_v1" "fiapx" {
  metadata {
    annotations = {
      "nginx.ingress.kubernetes.io/rewrite-target"     = "/$2"
      "nginx.ingress.kubernetes.io/use-regex"          = "true"
      "nginx.ingress.kubernetes.io/proxy-body-size"    = "500m"
      "nginx.ingress.kubernetes.io/proxy-read-timeout" = "300"
      "nginx.ingress.kubernetes.io/proxy-send-timeout" = "300"
    }
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      http {
        path { path = "/auth(/|$)(.*)"; backend { service { name = "auth-service", port { number = 8090 } } } }
        # ... demais paths por serviço
      }
    }
  }
}
```

**ADR relacionado:** ADR-001 (`auth` — JWT via Spring Security), ADR-004 (Banco de dados local por serviço), RFC-003 (Infraestrutura Kubernetes local), RFC-004 (Arquitetura geral e fluxo de mensageria).
