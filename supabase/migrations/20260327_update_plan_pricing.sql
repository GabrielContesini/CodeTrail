update public.plans
set
  description = 'Acesso completo aos recursos premium do produto.',
  price_cents = 2500,
  interval = 'month'
where code = 'pro';

update public.plans
set
  description = 'Plano anual com todos os recursos do Pro e condição especial para membros fundadores.',
  price_cents = 27000,
  interval = 'year'
where code = 'founding';
