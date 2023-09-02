--------------------------------------------------
-- ROTEIRO DE PERFORMANCE PARA BASES DE DADOS
--------------------------------------------------
/*
Melhorar o custo de memória de um banco de dados, pode ser algo muito pessoal variando de situacao
para situacao, qual a melhor situacao a ser desenvolvida, seria estipulada por um profissional DBA da 
empresa, que olharia a premissa necessária e assim teria uma ideia de onde partir. Os problemas das bases 
de dados, nem sempre vao se resolver com apenas uma alteracao, é necessario colocar index, tirar index, mudar 
querie, etc. É um processo que leva tempo, e que possui diversas maneiras de se resolver, e aquela que
nao mude muito a arquitetura de sua base e ainda assim melhore consideravelmente a performance, é a mais viável.

Padrões conhecidos que são aplicáveis em 90% das situacoes:
#1: Implementar índice nonclustered ou mudar índice clustered (no exemplo que será mostrado, montaremos a PK sendo a chave que será a FK de sua outra tabela)
#2: Tabela "in-memory" "as is" (utilizando o as is nas escritas e uma tabela em memoria local)
#3: Tabela "in-memory" PK sendo a chave referenciada (escrevendo a tabela em memória local e mudando a PK para a que está sendo referenciada como FK)
#4: Tabela "in-memory" indice hash (mesma premissa de escrita em memoria, porém agora gerando um index com um hash)
 

-------------------------------------------------
-- Métodos para medição de performance - "O que não se mede, não se gerencia!" - Edwards Deming
--------------------------------------------------

Os métodos abaixo, são metodos simples que são utilizados para verificação do processo de memória que o banco 
acaba exercendo, ou o estresse que ta ocorrendo no mesmo demonstrando o tempo de desempenho
*/

use exempo -- database utilizado para os exemplos abaixo
go
 
-- #1: Execution Plan: CONTROL + M (Abrirá uma aba a direita depois que o script for rodado que demonstra o plano completo de execucao do script lancado)
select top 100 * from tabela1 -- tabela que será usada para exemplos
go
 
-- #2: Client Execution Statistics: SHIFT + ALT + S (Abrirá uma aba a direita depois que o script for rodado que  Compara dados de cada execução. Para resetar "Menu Query; Reset Client Statistics")
select top 100 * from tabela1
go
 
-- #3: set statistics io/time on-off (Verificacao através do próprio código digitado)
set statistics io on
set statistics time on
select top 100 * from tabela1
set statistics io off
set statistics time off
go
 
-- #4: Getdate() - medidas em milisegundos (1s / 1000) (Medicao do tempo levado para execucao da determinada querie)
declare @dt_exemplo datetime = getdate() -- variavel que será usada para próximos eventos
select top 100 * from tabela1
print 'Resultado: ' + convert(varchar, getdate() - @dt_exemplo, 114)
go
 
-- #5: Sysdatetime() - medidas em microsegundos (1s / 1 milhão)
declare @dt_exemplo datetime2 = sysdatetime()
select top 100 * from tabela1
print concat('Resultado: ', right(concat('0', datediff(d, @dt_exemplo, sysdatetime())), 2), ' dias ', convert(varchar, convert(datetime, sysdatetime()) - convert(datetime, @dt_exemplo), 108), '.', right('000000' + convert(varchar, convert(bigint, datediff_big(microsecond, @dt_exemplo, sysdatetime()) % 1000000.0)), 6))
go

--------------------------------------------------
-- Montando cenários de teste
--------------------------------------------------
-- Apagar tabelas de teste caso existam
if object_id('tabela1_p1') is not null drop table tabela1_p1
if object_id('tabela1_p2') is not null drop table tabela1_p2
if object_id('tabela1_p3') is not null drop table tabela1_p3
if object_id('tabela1_p4') is not null drop table tabela1_p4
go
 
-- #1: Criar tabela de testes para proposta #1:
create table tabela1_P1 (
id_tabela1 int not null,
dt_atualizacao datetime null,
tp_tabela1 char(1) not null,
dt_tabela1 datetime not null,
ds_tabela1 varchar(50) not null,
constraint pk_tabela1_p1 primary key clustered (DT_tabela1) -- Alteracao da PK para a coluna de maior valor na memória (que seria referenciada em outras tabelas)
)
 
-- #2: Criar tabela de testes para proposta #2:
create table tabela1_P2 (
id_tabela1 int not null,
dt_atualizacao datetime null,
tp_tabela1 char(1) not null,
dt_tabela1 datetime not null,
ds_tabela1 varchar(50) not null,
constraint pk_tabela1_p2 primary key nonclustered (ID_tabela1) -- Quando uma aplicacao está in-memory, não é possível que a PK seja cluster pois só pode fazer conexoes com noncluster e em memória
) WITH (MEMORY_OPTIMIZED=ON, DURABILITY=SCHEMA_AND_DATA) -- Memory para dizer que está em memória e o durability para salvar o schema e os dados depois que o banco é resetado
 
-- #3: Criar tabela de testes para proposta #3:
create table tabela1_P3 (
id_tabela1 int not null,
dt_atualizacao datetime null,
tp_tabela1 char(1) not null,
dt_tabela1 datetime not null,
ds_tabela1 varchar(50) not null,
constraint pk_tabela1_p3 primary key nonclustered (DT_tabela1) -- Altero a PK para DT_tabela1 ao inv�s de ID_tabela1 (mantenho no modelo in-memory)
) WITH (MEMORY_OPTIMIZED=ON, DURABILITY=SCHEMA_AND_DATA)
go
 
-- #4: Criar tabela de testes para proposta #4:
create table tabela1_P4 (
id_tabela1 int not null,
dt_atualizacao datetime null,
tp_tabela1 char(1) not null,
dt_tabela1 datetime not null,
ds_tabela1 varchar(50) not null,
constraint pk_tabela1_p4 primary key nonclustered (ID_tabela1), -- Altero a PK para DT_tabela1 ao inv�s de ID_tabela1 (mantenho no modelo in-memory)
index ix_tabela1_p4 hash (dt_tabela1) with (bucket_count=1158) -- Para tabela est�tica defini o bucket-count = ao n�mero de registros.
) WITH (MEMORY_OPTIMIZED=ON, DURABILITY=SCHEMA_AND_DATA)
go
 
-- Migrar os dados para as tabelas de teste:
insert into tabela1_P1 select * from tabela1
insert into tabela1_P2 select * from tabela1
insert into tabela1_P3 select * from tabela1
insert into tabela1_P4 select * from tabela1
go
 
--------------------------------------------------
-- Comparar a performance das aplicacoes:
--------------------------------------------------
declare @dt_exemplo datetime2
declare @dt_inicio date = '2010-01-01'
declare @dt_final date = '2030-12-30'
 
-- #1 Cenário PK na DT_tabela1
set @dt_exemplo = sysdatetime()
select
count(dt_tabela1)
from tabela1_P1
where
dt_tabela1 between @dt_inicio and @dt_final
and datepart(dw, dt_tabela1) not in (7, 1) -- Sem contagem aos sábados e domingos
print concat('Resultado: ', right(concat('0', datediff(d, @dt_exemplo, sysdatetime())), 2), ' dias ', convert(varchar, convert(datetime, sysdatetime()) - convert(datetime, @dt_exemplo), 108), '.', right('000000' + convert(varchar, convert(bigint, datediff_big(microsecond, @dt_exemplo, sysdatetime()) % 1000000.0)), 6))

-- #2 Cenário em memória e padrão schema "as is"
set @dt_exemplo = sysdatetime()
select
count(dt_tabela1)
from tabela1_P2
where
dt_tabela1 between @dt_inicio and @dt_final
and datepart(dw, dt_tabela1) not in (7, 1)
print concat('Resultado: ', right(concat('0', datediff(d, @dt_exemplo, sysdatetime())), 2), ' dias ', convert(varchar, convert(datetime, sysdatetime()) - convert(datetime, @dt_exemplo), 108), '.', right('000000' + convert(varchar, convert(bigint, datediff_big(microsecond, @dt_exemplo, sysdatetime()) % 1000000.0)), 6))

-- #3 Cenário em memória e troca de PK 
set @dt_exemplo = sysdatetime()
select
count(dt_tabela1)
from tabela1_P3
where
dt_tabela1 between @dt_inicio and @dt_final
and datepart(dw, dt_tabela1) not in (7, 1)
print concat('Resultado: ', right(concat('0', datediff(d, @dt_exemplo, sysdatetime())), 2), ' dias ', convert(varchar, convert(datetime, sysdatetime()) - convert(datetime, @dt_exemplo), 108), '.', right('000000' + convert(varchar, convert(bigint, datediff_big(microsecond, @dt_exemplo, sysdatetime()) % 1000000.0)), 6))

-- #4 Cenário em memória com padrão de index hash
set @dt_exemplo = sysdatetime()
select
count(dt_tabela1)
from tabela1_P4
where
dt_tabela1 between @dt_iniciociociocio and @dt_final
and datepart(dw, dt_tabela1) not in (7, 1)
print concat('Resultado: ', right(concat('0', datediff(d, @dt_exemplo, sysdatetime())), 2), ' dias ', convert(varchar, convert(datetime, sysdatetime()) - convert(datetime, @dt_exemplo), 108), '.', right('000000' + convert(varchar, convert(bigint, datediff_big(microsecond, @dt_exemplo, sysdatetime()) % 1000000.0)), 6))
go

/*
NOS CASOS ACIMA, PERCEBA QUE A ÚNICA TROCA DENTRO DA QUERIE, É AONDE É PUXADA A TABELA, QUE É REFERENCIADA A TABELA QUE
ESTÁ SENDO USADA PARA O CENÁRIO, CASO CONTRÁRIO A RECEITA DE BOLO SE TORNA A MESMA
*/

