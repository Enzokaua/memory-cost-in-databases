select * from pessoa --O �CONE, DO LADO DO VERIFICADO PROXIMO AO BANCO DE DADOS, SERIA AONDE ENTRARIA O T�PICO DE PLANO DE EXECUCAO, QUE MOSTRARIA TODO O PLANO PELA EXECUCAO DA QUERIE EM QUESTAO
--O COMANDO DAS DUAS CALCULADORAS, PERTO DOS DOIS MODELOS DE PLANO DE EXECUCAO, � O DE ESTATISTICAS DO CLIENTE
--O MODELO DE ESTATISTICAS DO CLIENTE, DEMONSTRA TODAS AS ALTERACOES, INSTRUCOES, E DEMAIS COISAS FEITAS EM SUA BASE DE DADOS
-- ELE MOSTRARIA A HORA, E TODAS AS INFORMACOES NECESSARIAS DA SUA BASE
-- SE RODADA 2X, ELE COMPARARIA AS DUAS RUNS E DEMONSTRARIA QUAL TEVE MAIS TEMPO DE PERFORMANCE
--PARA RESETAR, � S� IR NA ABA DE CONSULTA, E REDEFINIR ESTATISTICAS DO CLIENTE, ASSIM DA PARA INICIAR NOVAMENTE O COMPARADOR

print 'hello word' -- CONSOLE LOG DO SQL

--------------------------------------------------
-- M�todos para medi��o de performance - "O que n�o se mede, n�o se gerencia!" - Edwards Deming
--------------------------------------------------
use curso
go
 
-- #1: Execution Plan: CONTROL + M
select top 100 * from feriado
go
 
-- #2: Client Execution Statistics: SHIFT + ALT + S (Compara dados de cada execu��o. Para resetar "Menu Query &amp;amp;amp;amp;amp;amp;gt; Reset Client Statistics")
select top 100 * from feriado
go
 
-- #3: set statistics io/time on-off
set statistics io on
set statistics time on
select top 100 * from feriado
set statistics io off
set statistics time off
go
 
-- #4: Getdate() - medidas em milisegundos (1s / 1000)
declare @dt_ini_rotina datetime = getdate()
select top 100 * from feriado
print 'Conclu�do: ' + convert(varchar, getdate() - @dt_ini_rotina, 114)
go
 
-- #5: Sysdatetime() - medidas em microsegundos (1s / 1 milh�o)
declare @dt_ini_rotina datetime2 = sysdatetime()
select top 100 * from feriado
print concat('Conclu�do: ', right(concat('0', datediff(d, @dt_ini_rotina, sysdatetime())), 2), ' dias ', convert(varchar, convert(datetime, sysdatetime()) - convert(datetime, @dt_ini_rotina), 108), '.', right('000000' + convert(varchar, convert(bigint, datediff_big(microsecond, @dt_ini_rotina, sysdatetime()) % 1000000.0)), 6))
go

--------------------------------------------------
-- Cen�rios de melhoria
--------------------------------------------------
/*
#0: Manter "as is"
#1: Implementar �ndice nonclustered ou mudar �ndice clustered (nesse exemplo, mudar para DT_FERIADO)
#2: Tabela "in-memory" "as is"
#3: Tabela "in-memory" PK na coluna DT_FERIADO
#4: Tabela "in-memory" indice hash na coluna DT_FERIADO
 
OBS: Existem N estrat�gias de performance que n�o veremos aqui por n�o serem aplic�veis ao exemplo, ex:
Particionamento: Tabela muito pequena para fazer sentido.
Aloca��o em diferentes filegroups: Tabela muito pequena para fazer sentido.
Historifica��o de dados: Todos os dados s�o de produ��o (tabela de dom�nio). N�o h� dados hist�ricos.
View indexada (trata-se de apenas 1 tabela, logo, faz mais sentido um indice direto a uma view indexada)
Etc...
 --------------------------------------------------
-- Requisitos do cen�rio in-memory
--------------------------------------------------
-- Adicionar FG com suporte para tabelas em mem�ria:
alter database curso add filegroup Curso_MOD contains memory_optimized_data
go
alter database curso add file (name='Curso_MOD_01', filename='c:\tmp\Curso_MOD_01.ndf') to filegroup Curso_MOD
go
 */
--------------------------------------------------
-- Montando cen�rios de teste
--------------------------------------------------
-- Apagar tabelas de teste caso existam
if object_id('feriado_p1') is not null drop table feriado_p1
if object_id('feriado_p2') is not null drop table feriado_p2
if object_id('feriado_p3') is not null drop table feriado_p3
if object_id('feriado_p4') is not null drop table feriado_p4
go
 
-- #1: Criar tabela de testes para proposta #1:
create table feriado_P1 (
id_feriado int not null,
dt_atualizacao datetime null,
tp_feriado char(1) not null,
dt_feriado datetime not null,
ds_feriado varchar(50) not null,
constraint pk_feriado_p1 primary key clustered (DT_FERIADO) -- Altero a PK para DT_FERIADO ao inv�s de ID_FERIADO
)
 
-- #2: Criar tabela de testes para proposta #2:
create table feriado_P2 (
id_feriado int not null,
dt_atualizacao datetime null,
tp_feriado char(1) not null,
dt_feriado datetime not null,
ds_feriado varchar(50) not null,
constraint pk_feriado_p2 primary key nonclustered (ID_FERIADO) -- in-memory n�o pode ter PK clustered. Na proposta 2, mantenho a pk na mesma coluna.
) WITH (MEMORY_OPTIMIZED=ON, DURABILITY=SCHEMA_AND_DATA) -- DURABILITY=SCHEMA_AND_DATA | SCHEMA_ONLY
 
-- #3: Criar tabela de testes para proposta #3:
create table feriado_P3 (
id_feriado int not null,
dt_atualizacao datetime null,
tp_feriado char(1) not null,
dt_feriado datetime not null,
ds_feriado varchar(50) not null,
constraint pk_feriado_p3 primary key nonclustered (DT_FERIADO) -- Altero a PK para DT_FERIADO ao inv�s de ID_FERIADO (mantenho no modelo in-memory)
) WITH (MEMORY_OPTIMIZED=ON, DURABILITY=SCHEMA_AND_DATA)
go
 
-- #4: Criar tabela de testes para proposta #4:
create table feriado_P4 (
id_feriado int not null,
dt_atualizacao datetime null,
tp_feriado char(1) not null,
dt_feriado datetime not null,
ds_feriado varchar(50) not null,
constraint pk_feriado_p4 primary key nonclustered (ID_FERIADO), -- Altero a PK para DT_FERIADO ao inv�s de ID_FERIADO (mantenho no modelo in-memory)
index ix_feriado_p4 hash (dt_feriado) with (bucket_count=1158) -- Para tabela est�tica defini o bucket-count = ao n�mero de registros.
) WITH (MEMORY_OPTIMIZED=ON, DURABILITY=SCHEMA_AND_DATA)
go
 
-- Migrar os dados para as tabelas de teste:
insert into feriado_P1 select * from feriado
insert into feriado_P2 select * from feriado
insert into feriado_P3 select * from feriado
insert into feriado_P4 select * from feriado
go
 
--------------------------------------------------
-- Comparar a performance (tempo &amp;amp;amp;amp;amp;amp;amp; plano de execu��o):
--------------------------------------------------
declare @dt_ini_rotina datetime2
declare @dt_ini date = '2010-01-01'
declare @dt_fim date = '2030-12-30'
 
-- #0 Cen�rio atual
set @dt_ini_rotina = sysdatetime()
select
count(dt_feriado)
from feriado
where
dt_feriado between @dt_ini and @dt_fim
and datepart(dw, dt_feriado) not in (7, 1) -- N�o conta feriados em S�bados e Dom�ngo
print concat('Conclu�do: ', right(concat('0', datediff(d, @dt_ini_rotina, sysdatetime())), 2), ' dias ', convert(varchar, convert(datetime, sysdatetime()) - convert(datetime, @dt_ini_rotina), 108), '.', right('000000' + convert(varchar, convert(bigint, datediff_big(microsecond, @dt_ini_rotina, sysdatetime()) % 1000000.0)), 6))
-- #1 Cen�rio PK na DT_FERIADO
set @dt_ini_rotina = sysdatetime()
select
count(dt_feriado)
from feriado_P1 -- !!! MUDEI A QUERY APENAS AQUI !!!!
where
dt_feriado between @dt_ini and @dt_fim
and datepart(dw, dt_feriado) not in (7, 1) -- N�o conta feriados em S�bados e Dom�ngo
print concat('Conclu�do: ', right(concat('0', datediff(d, @dt_ini_rotina, sysdatetime())), 2), ' dias ', convert(varchar, convert(datetime, sysdatetime()) - convert(datetime, @dt_ini_rotina), 108), '.', right('000000' + convert(varchar, convert(bigint, datediff_big(microsecond, @dt_ini_rotina, sysdatetime()) % 1000000.0)), 6))
-- #2 Cen�rio in-memory schema "as is"
set @dt_ini_rotina = sysdatetime()
select
count(dt_feriado)
from feriado_P2 -- !!! MUDEI A QUERY APENAS AQUI !!!!
where
dt_feriado between @dt_ini and @dt_fim
and datepart(dw, dt_feriado) not in (7, 1) -- N�o conta feriados em S�bados e Dom�ngo
print concat('Conclu�do: ', right(concat('0', datediff(d, @dt_ini_rotina, sysdatetime())), 2), ' dias ', convert(varchar, convert(datetime, sysdatetime()) - convert(datetime, @dt_ini_rotina), 108), '.', right('000000' + convert(varchar, convert(bigint, datediff_big(microsecond, @dt_ini_rotina, sysdatetime()) % 1000000.0)), 6))
-- #3 Cen�rio in-memory PK na coluna DT_FERIADO
set @dt_ini_rotina = sysdatetime()
select
count(dt_feriado)
from feriado_P3 -- !!! MUDEI A QUERY APENAS AQUI !!!!
where
dt_feriado between @dt_ini and @dt_fim
and datepart(dw, dt_feriado) not in (7, 1) -- N�o conta feriados em S�bados e Dom�ngo
print concat('Conclu�do: ', right(concat('0', datediff(d, @dt_ini_rotina, sysdatetime())), 2), ' dias ', convert(varchar, convert(datetime, sysdatetime()) - convert(datetime, @dt_ini_rotina), 108), '.', right('000000' + convert(varchar, convert(bigint, datediff_big(microsecond, @dt_ini_rotina, sysdatetime()) % 1000000.0)), 6))
-- #4 Cen�rio in-memory �ndice hash na coluna DT_FERIADO
set @dt_ini_rotina = sysdatetime()
select
count(dt_feriado)
from feriado_P4 -- !!! MUDEI A QUERY APENAS AQUI !!!!
where
dt_feriado between @dt_ini and @dt_fim
and datepart(dw, dt_feriado) not in (7, 1) -- N�o conta feriados em S�bados e Dom�ngo
print concat('Conclu�do: ', right(concat('0', datediff(d, @dt_ini_rotina, sysdatetime())), 2), ' dias ', convert(varchar, convert(datetime, sysdatetime()) - convert(datetime, @dt_ini_rotina), 108), '.', right('000000' + convert(varchar, convert(bigint, datediff_big(microsecond, @dt_ini_rotina, sysdatetime()) % 1000000.0)), 6))
go