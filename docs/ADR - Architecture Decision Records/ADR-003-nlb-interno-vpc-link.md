# ADR-003 — NLB Interno com VPC Link como Padrão de Comunicação entre API Gateway e EKS

| Campo        | Valor                                                                   |
|--------------|-------------------------------------------------------------------------|
| **ADR**      | 003                                                                     |
| **Título**   | NLB interno + VPC Link como único caminho de entrada para o cluster EKS |
| **Repositório** | fiap-14soat-tc-fase4-iac-terraform                                     |
| **Status**   | Aceito                                                                  |
| **Data**     | 2026-04-20 (criado) · 2026-07-17 (revisado para Fase 4)                 |
| **Decisores**| Time FIAP 14SOAT Fase 4 — RaceForce                                     |

---

## Contexto

Após provisionar o cluster EKS, a equipe precisou definir como o **API Gateway (externo)** alcançaria os pods internos do cluster. As opções avaliadas foram:

1. **LoadBalancer Service** público no Kubernetes (cria NLB público automaticamente);
2. **NLB interno + VPC Link** (NLB sem IP público, acessado apenas via VPC Link);
3. **Ingress Controller** (ex: AWS Load Balancer Controller + ALB Ingress);
4. **NodePort direto** com Security Group abrindo a porta 30000 na internet.

---

## Decisão

**Provisionar um NLB com `internal = true` via Terraform**, conectado ao API Gateway por meio de um **VPC Link privado**. O Kubernetes Service permanece como `NodePort`, e o NLB aponta para os nodes nas portas 30000 (app) / 8080 (Adminer) / 8025 (MailHog).

---

## Justificativa

| Critério | NLB público | NLB interno + VPC Link (escolhido) | Ingress ALB | NodePort público |
|----------|-------------|-------------------------------------|-------------|-----------------|
| Segurança | Exposto na internet | Não exposto | Exposto via ALB | Altamente exposto |
| Custo | NLB = ~$16/mês | Idem (mas sem IP público) | ALB = ~$20/mês + LCU | Sem custo adicional |
| Controle de acesso | Security Group | Security Group + VPC Link privado | Ingress rules | Security Group |
| Compatibilidade com API Gateway HTTP v2 | Sim (via VPC Link) | **Sim — path recomendado pela AWS** | Não nativo | Não recomendado |
| Gestão no Terraform | `aws_lb` | `aws_lb` + `aws_apigatewayv2_vpc_link` | `aws_lb` + controller | Sem recurso |

O **NLB interno + VPC Link** foi escolhido porque:
- O API Gateway HTTP v2 usa VPC Link para acessar recursos privados — é o **padrão oficial AWS**;
- O NLB não fica exposto na internet, reduzindo superfície de ataque;
- Toda requisição externa **obrigatoriamente passa pelo API Gateway** (com Lambda Authorizer);
- Terraform gerencia o VPC Link como recurso de primeira classe (`aws_apigatewayv2_vpc_link`).

---

## Consequências

### Positivas
- **Zero exposição pública do EKS** — o único endpoint externo é o API Gateway;
- Arquitetura alinhada com boas práticas AWS Well-Architected Framework (pilar Segurança);
- NLB opera na camada 4 (TCP), adicionando mínima latência;
- VPC Link estabelece conexão persistente entre Gateway e VPC, sem overhead de HTTPS adicional.

### Negativas / Riscos
- VPC Link pode levar 5-10 minutos para ficar disponível após `terraform apply`;
- Se o NLB não encontrar nodes com a porta aberta (NodePort), retorna 502 Bad Gateway no API Gateway — debug requer verificação do Target Group do NLB;
- Adminer e MailHog usam LoadBalancer Services separados (exposição pública necessária para acesso da equipe no AWS Academy).

---

## Alternativas Consideradas

### Ingress Controller (AWS Load Balancer Controller + ALB)
- Mais funcional (path-based routing, SSL termination);
- Mais complexo de instalar no AWS Academy (requer IRSA, OpenID Connect no EKS);
- Custo adicional (ALB + LCU);
- Não necessário para o escopo atual.

### NodePort público (Security Group aberto)
- Simples, mas inseguro;
- Bypassa completamente o API Gateway e o Lambda Authorizer;
- Inaceitável para o requisito de autenticação.

---

## Notas de Implementação

```hcl
# nlb.tf
resource "aws_lb" "eks_nlb" {
  name               = "${var.project_identifier}-nlb"
  internal           = true   # NÃO público
  load_balancer_type = "network"
  subnets            = aws_subnet.publicas[*].id
}

# api-gateway.tf (auth-lambda)
resource "aws_apigatewayv2_vpc_link" "eks" {
  name               = "${var.project_identifier}-vpc-link"
  security_group_ids = [aws_security_group.vpc_link_sg.id]
  subnet_ids         = data.terraform_remote_state.infra.outputs.subnet_publica_ids
}
```

**ADR relacionado:** ADR-001 (Lambda Authorizer), RFC-003 (Infra Kubernetes).

