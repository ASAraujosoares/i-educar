--
-- PostgreSQL database dump
--

\restrict mzdzcgw27YG4b4RVMLM5H0PIzma5XE5EXtu1cQGzuMZQZLI8BdKKZi8b08L7xnC

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: cadastro; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA cadastro;


--
-- Name: modules; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA modules;


--
-- Name: pmieducar; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA pmieducar;


--
-- Name: portal; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA portal;


--
-- Name: relatorio; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA relatorio;


--
-- Name: fuzzystrmatch; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS fuzzystrmatch WITH SCHEMA public;


--
-- Name: EXTENSION fuzzystrmatch; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION fuzzystrmatch IS 'determine similarities and distance between strings';


--
-- Name: hstore; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS hstore WITH SCHEMA relatorio;


--
-- Name: EXTENSION hstore; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION hstore IS 'data type for storing sets of (key, value) pairs';


--
-- Name: unaccent; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;


--
-- Name: EXTENSION unaccent; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';


--
-- Name: typ_idlog; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.typ_idlog AS (
	idlog integer
);


--
-- Name: typ_idpes; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.typ_idpes AS (
	idpes integer
);


--
-- Name: fcn_aft_documento(); Type: FUNCTION; Schema: cadastro; Owner: -
--

CREATE FUNCTION cadastro.fcn_aft_documento() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
                DECLARE
                  v_idpes   numeric;
                  BEGIN
                    v_idpes := NEW.idpes;
                    EXECUTE E'DELETE FROM cadastro.documento WHERE ( (rg = \'0\' OR rg IS NULL) AND (idorg_exp_rg IS NULL) AND data_exp_rg IS NULL AND (sigla_uf_exp_rg IS NULL OR length(trim(sigla_uf_exp_rg))=0) AND (tipo_cert_civil = 0 OR tipo_cert_civil IS NULL) AND (num_termo = 0 OR num_termo IS NULL) AND (num_livro = \'0\' OR num_livro IS NULL) AND (num_livro = \'0\' OR num_livro IS NULL) AND (num_folha = 0 OR num_folha IS NULL) AND data_emissao_cert_civil IS NULL AND (sigla_uf_cert_civil IS NULL OR length(trim(sigla_uf_cert_civil))=0) AND (sigla_uf_cart_trabalho IS NULL OR length(trim(sigla_uf_cart_trabalho))=0) AND (cartorio_cert_civil IS NULL OR length(trim(cartorio_cert_civil))=0) AND (num_cart_trabalho = 0 OR num_cart_trabalho IS NULL) AND (serie_cart_trabalho = 0 OR serie_cart_trabalho IS NULL) AND data_emissao_cart_trabalho IS NULL AND (num_tit_eleitor = 0 OR num_tit_eleitor IS NULL) AND (zona_tit_eleitor = 0 OR zona_tit_eleitor IS NULL) AND (secao_tit_eleitor = 0 OR secao_tit_eleitor IS NULL) ) AND idpes='||quote_literal(v_idpes)||' AND certidao_nascimento is null';
                  RETURN NEW;
                END; $$;


--
-- Name: fcn_aft_documento_provisorio(); Type: FUNCTION; Schema: cadastro; Owner: -
--

CREATE FUNCTION cadastro.fcn_aft_documento_provisorio() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  DECLARE
    v_idpes       numeric;
    v_rg        text;
    v_uf_expedicao      text;
    v_verificacao_provisorio  numeric;

    v_comando     text;
    v_registro      record;

    BEGIN
      v_idpes     := NEW.idpes;
      v_rg      := COALESCE(NEW.rg, '-1');
      v_uf_expedicao    := TRIM(COALESCE(NEW.sigla_uf_exp_rg, ''));

      v_verificacao_provisorio:= 0;

      -- verificar se a situação do cadastro da pessoa é provisório
      FOR v_registro IN SELECT situacao FROM cadastro.pessoa WHERE idpes=v_idpes LOOP
        IF v_registro.situacao = 'P' THEN
          v_verificacao_provisorio := 1;
        END IF;
      END LOOP;

      -- Verificação para atualizar ou não a situação do cadastro da pessoa para Ativo
      IF LENGTH(v_uf_expedicao) > 0 AND v_rg != '' AND v_rg != '-1' AND v_verificacao_provisorio = 1 THEN
        EXECUTE 'UPDATE cadastro.pessoa SET situacao='||quote_literal('A')||'WHERE idpes='||quote_literal(v_idpes)||';';
      END IF;
    RETURN NEW;
  END; $$;


--
-- Name: frequencia_da_matricula(integer); Type: FUNCTION; Schema: modules; Owner: -
--

CREATE FUNCTION modules.frequencia_da_matricula(p_matricula_id integer) RETURNS double precision
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_regra_falta integer;
    v_falta_aluno_id  integer;
    v_qtd_dias_letivos_serie NUMERIC;
    v_total_faltas integer;
    v_qtd_horas_serie integer;
    v_total_hora_falta FLOAT;
BEGIN
    /*
        v_regra_falta:
        1- Global
        2- Por componente
    */
    v_regra_falta:= (
        SELECT regra_avaliacao.tipo_presenca
        FROM pmieducar.matricula
                 INNER JOIN pmieducar.serie
                            ON serie.cod_serie = matricula.ref_ref_cod_serie
                 INNER JOIN modules.regra_avaliacao_serie_ano rasa
                            ON serie.cod_serie = rasa.serie_id
                                AND rasa.ano_letivo = matricula.ano
                 INNER JOIN modules.regra_avaliacao
                            ON regra_avaliacao.id = rasa.regra_avaliacao_id
        WHERE matricula.cod_matricula = p_matricula_id
    );
    v_falta_aluno_id := (
        SELECT id
        FROM modules.falta_aluno
        WHERE matricula_id = p_matricula_id
        ORDER BY id DESC
        LIMIT 1
    );
    IF (v_regra_falta = 1) THEN
        v_qtd_dias_letivos_serie := (
            SELECT s.dias_letivos
            FROM pmieducar.serie s
                     INNER JOIN pmieducar.matricula m
                                ON (m.ref_ref_cod_serie = s.cod_serie)
            WHERE m.cod_matricula = p_matricula_id
        );
        v_total_faltas := (
            SELECT SUM(quantidade)
            FROM modules.falta_geral
            WHERE falta_aluno_id = v_falta_aluno_id
        );

        RETURN TRUNC((((v_qtd_dias_letivos_serie - v_total_faltas) * 100 ) / v_qtd_dias_letivos_serie )::numeric,1);
    ELSE

        v_qtd_horas_serie := (
            SELECT s.carga_horaria
            FROM pmieducar.serie s
                     INNER JOIN pmieducar.matricula m
                                ON (m.ref_ref_cod_serie = s.cod_serie)
            WHERE m.cod_matricula = p_matricula_id
        );

        v_total_hora_falta := (
            /*
               Soma todos so sub_totais que foram calculados individualmente
             */
            SELECT sum(sub_totais.totais) from (
                SELECT
                    /*
                        Calcula para cada componente curricular seu total de horas faltas
                        com base na carga horaria do componente.
                        Foi aplicado o (* 100) que estava no retorno da função no retor na quantidade de horas falta
                        do componente curricular
                    */
                    SUM(fcc.quantidade) * (modules.hora_falta_por_componente(p_matricula_id, fcc.componente_curricular_id)::float * 100)::float as "totais"
                    FROM modules.falta_componente_curricular fcc
                    WHERE fcc.falta_aluno_id = v_falta_aluno_id
                    GROUP BY fcc.componente_curricular_id
                ) as sub_totais
        );

        RETURN  TRUNC((100 - ( v_total_hora_falta / v_qtd_horas_serie))::numeric, 1);
    END IF;
END;
$$;


--
-- Name: frequencia_por_componente(integer, integer, integer); Type: FUNCTION; Schema: modules; Owner: -
--

CREATE FUNCTION modules.frequencia_por_componente(cod_matricula_id integer, cod_disciplina_id integer, cod_turma_id integer) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
    cod_falta_aluno_id integer;
    v_total_faltas integer;
    qtde_carga_horaria float;
    v_hora_falta float;
    cod_serie_id integer;
    cod_escola_id integer;
BEGIN

    cod_falta_aluno_id := (SELECT id FROM modules.falta_aluno WHERE matricula_id = cod_matricula_id ORDER BY id DESC LIMIT 1);
	cod_escola_id := (SELECT t.ref_ref_cod_escola FROM pmieducar.turma t WHERE cod_turma = cod_turma_id);

    qtde_carga_horaria := (
        SELECT carga_horaria :: float
        FROM modules.componente_curricular_turma
        WHERE componente_curricular_turma.componente_curricular_id = cod_disciplina_id
        AND componente_curricular_turma.turma_id = cod_turma_id
    );

    cod_serie_id := (
        SELECT ref_ref_cod_serie
        FROM pmieducar.matricula
        WHERE cod_matricula = cod_matricula_id
    );

    IF (qtde_carga_horaria IS NULL) THEN
        qtde_carga_horaria := (
            SELECT carga_horaria :: float
            FROM pmieducar.escola_serie_disciplina
            WHERE escola_serie_disciplina.ref_cod_disciplina = cod_disciplina_id
            AND escola_serie_disciplina.ref_ref_cod_serie = cod_serie_id
            AND escola_serie_disciplina.ref_ref_cod_escola = cod_escola_id);
    END IF;

    IF (qtde_carga_horaria IS NULL) THEN
        qtde_carga_horaria := (
            SELECT carga_horaria :: float
            FROM modules.componente_curricular_ano_escolar
            WHERE componente_curricular_ano_escolar.componente_curricular_id = cod_disciplina_id
            AND componente_curricular_ano_escolar.ano_escolar_id = cod_serie_id
        );
    END IF;

    v_total_faltas := (
        SELECT SUM(quantidade)
        FROM modules.falta_componente_curricular
        WHERE falta_aluno_id = cod_falta_aluno_id
          AND componente_curricular_id = cod_disciplina_id
    );

    v_hora_falta := (
        SELECT hora_falta :: float
        FROM pmieducar.escola_serie_disciplina
        WHERE escola_serie_disciplina.ref_cod_disciplina = cod_disciplina_id
        AND escola_serie_disciplina.ref_ref_cod_serie = cod_serie_id
        AND escola_serie_disciplina.ref_ref_cod_escola = cod_escola_id
    );

    IF (v_hora_falta IS NULL) THEN
        v_hora_falta := (
            SELECT hora_falta :: float
            FROM modules.componente_curricular_ano_escolar
            WHERE componente_curricular_ano_escolar.componente_curricular_id = cod_disciplina_id
            AND componente_curricular_ano_escolar.ano_escolar_id = cod_serie_id
        );
    END IF;

    IF (v_hora_falta IS NULL) THEN
        v_hora_falta := (
	        SELECT hora_falta
	        FROM pmieducar.curso c
	        INNER JOIN pmieducar.matricula m
	        ON (c.cod_curso = m.ref_cod_curso)
	        WHERE m.cod_matricula = cod_matricula_id
	   );
    END IF;

    IF (qtde_carga_horaria = 0) THEN
        RETURN 0;
    END IF;

    RETURN  trunc((100 - ((v_total_faltas * (v_hora_falta*100))/qtde_carga_horaria))::numeric, 1);

END;
$$;


--
-- Name: hora_falta_por_componente(integer, integer); Type: FUNCTION; Schema: modules; Owner: -
--

CREATE FUNCTION modules.hora_falta_por_componente(cod_matricula_id integer, cod_disciplina_id integer) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_hora_falta float;
    cod_serie_id integer;
    cod_escola_id integer;
BEGIN

	cod_escola_id := (
        SELECT ref_ref_cod_escola
        FROM pmieducar.matricula
        WHERE cod_matricula = cod_matricula_id
    );

    cod_serie_id := (
        SELECT ref_ref_cod_serie
        FROM pmieducar.matricula
        WHERE cod_matricula = cod_matricula_id
    );

    v_hora_falta := (
        SELECT hora_falta :: float
        FROM pmieducar.escola_serie_disciplina
        WHERE escola_serie_disciplina.ref_cod_disciplina = cod_disciplina_id
        AND escola_serie_disciplina.ref_ref_cod_serie = cod_serie_id
        AND escola_serie_disciplina.ref_ref_cod_escola = cod_escola_id
    );

    IF (v_hora_falta IS NULL) THEN
        v_hora_falta := (
            SELECT hora_falta :: float
            FROM modules.componente_curricular_ano_escolar
            WHERE componente_curricular_ano_escolar.componente_curricular_id = cod_disciplina_id
            AND componente_curricular_ano_escolar.ano_escolar_id = cod_serie_id
        );
    END IF;


    IF (v_hora_falta IS NULL) THEN
        v_hora_falta := (
            SELECT hora_falta
            FROM pmieducar.curso c
                     INNER JOIN pmieducar.matricula m ON (c.cod_curso = m.ref_cod_curso)
            WHERE m.cod_matricula = cod_matricula_id
        );
    END IF;

    RETURN  v_hora_falta;

END;
$$;


--
-- Name: copiaanosletivos(smallint, integer); Type: FUNCTION; Schema: pmieducar; Owner: -
--

CREATE FUNCTION pmieducar.copiaanosletivos(ianonovo smallint, icodescola integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
            DECLARE
            iAnoAnterior smallint;
            BEGIN

            SELECT COALESCE(MAX(ano),0) INTO iAnoAnterior
            FROM pmieducar.escola_ano_letivo
            WHERE ref_cod_escola = iCodEscola
            AND ano < iAnoNovo;

            If iAnoAnterior IS NOT NULL THEN

                UPDATE pmieducar.escola_curso
                SET anos_letivos = array_append(anos_letivos, iAnoNovo)
                WHERE iAnoAnterior = ANY(anos_letivos)
                AND NOT (iAnoNovo = ANY(anos_letivos))
                AND ref_cod_escola = iCodEscola;

                UPDATE pmieducar.escola_serie
                SET anos_letivos = array_append(anos_letivos, iAnoNovo)
                WHERE iAnoAnterior = ANY(anos_letivos)
                AND NOT (iAnoNovo = ANY(anos_letivos))
                AND ref_cod_escola = iCodEscola;

                UPDATE pmieducar.escola_serie_disciplina
                SET anos_letivos = array_append(anos_letivos, iAnoNovo)
                WHERE iAnoAnterior = ANY(anos_letivos)
                AND NOT (iAnoNovo = ANY(anos_letivos))
                AND ref_ref_cod_escola = iCodEscola;

                UPDATE modules.componente_curricular_ano_escolar
                SET anos_letivos = array_append(anos_letivos, iAnoNovo)
                WHERE EXISTS(
                    SELECT 1
                    FROM pmieducar.escola_serie_disciplina
                    WHERE iAnoAnterior = ANY(anos_letivos)
                    AND ref_ref_cod_escola = iCodEscola
                    AND escola_serie_disciplina.ref_cod_disciplina = componente_curricular_ano_escolar.componente_curricular_id
                    AND escola_serie_disciplina.ref_ref_cod_serie = componente_curricular_ano_escolar.ano_escolar_id
                )
                AND NOT (iAnoNovo = ANY(anos_letivos));

                INSERT INTO modules.regra_avaliacao_serie_ano
                (serie_id, regra_avaliacao_id, regra_avaliacao_diferenciada_id, ano_letivo)
                SELECT distinct serie, rasa.regra_avaliacao_id, rasa.regra_avaliacao_diferenciada_id, iAnoNovo
                FROM (
                SELECT distinct ref_cod_serie serie
                FROM pmieducar.escola_serie
                WHERE iAnoAnterior = ANY(anos_letivos)
                AND ref_cod_escola = iCodEscola
                ) AS myqq
                JOIN modules.regra_avaliacao_serie_ano rasa
                ON rasa.serie_id = serie
                AND iAnoAnterior = rasa.ano_letivo
                AND NOT EXISTS(
                    SELECT 1
                    FROM modules.regra_avaliacao_serie_ano
                    WHERE serie_id = rasa.serie_id
                    AND ano_letivo = iAnoNovo
                );

            END IF;
            END;
            $$;


--
-- Name: delete_matricula_turma(); Type: FUNCTION; Schema: pmieducar; Owner: -
--

CREATE FUNCTION pmieducar.delete_matricula_turma() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO pmieducar.matricula_turma_excluidos (
        id,
        ref_cod_matricula,
        ref_cod_turma,
        sequencial,
        ref_usuario_exc,
        ref_usuario_cad,
        data_cadastro,
        data_exclusao,
        ativo,
        data_enturmacao,
        sequencial_fechamento,
        transferido,
        remanejado,
        reclassificado,
        abandono,
        updated_at,
        falecido,
        etapa_educacenso,
        turma_unificada,
        deleted_at
    )
    VALUES (
        OLD.id,
        OLD.ref_cod_matricula,
        OLD.ref_cod_turma,
        OLD.sequencial,
        OLD.ref_usuario_exc,
        OLD.ref_usuario_cad,
        OLD.data_cadastro,
        OLD.data_exclusao,
        OLD.ativo,
        OLD.data_enturmacao,
        OLD.sequencial_fechamento,
        OLD.transferido,
        OLD.remanejado,
        OLD.reclassificado,
        OLD.abandono,
        OLD.updated_at,
        OLD.falecido,
        OLD.etapa_educacenso,
        OLD.turma_unificada,
        NOW()
    );
    RETURN OLD;
END;
$$;


--
-- Name: get_date_in_year(integer, date); Type: FUNCTION; Schema: pmieducar; Owner: -
--

CREATE FUNCTION pmieducar.get_date_in_year(year integer, date date) RETURNS date
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TO_CHAR(date, 'mm-dd') <> '02-29' THEN
        RETURN year || TO_CHAR(date, '-mm-dd');
    END IF;

    IF (SELECT (year % 4 = 0) AND ((year % 100 <> 0) or (year % 400 = 0))) THEN
        RETURN year || TO_CHAR(date, '-mm-dd');
    ELSE
        RETURN year || TO_CHAR(date - INTERVAL '1 DAY', '-mm-dd');
    END IF;
END;
$$;


--
-- Name: updated_at_matricula(); Type: FUNCTION; Schema: pmieducar; Owner: -
--

CREATE FUNCTION pmieducar.updated_at_matricula() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;


--
-- Name: updated_at_matricula_turma(); Type: FUNCTION; Schema: pmieducar; Owner: -
--

CREATE FUNCTION pmieducar.updated_at_matricula_turma() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;


--
-- Name: audit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.audit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
	if (audit_enabled() = false) then
		return null;
	end if;

	if (TG_OP = 'DELETE') then
		insert into ieducar_audit ("date", "schema", "table", "context", "before", "after")
		values (now(), TG_TABLE_SCHEMA::text, TG_TABLE_NAME::text, audit_context(), to_json(old.*), null);

		return old;
	end if;

	if (TG_OP = 'UPDATE') then
		insert into ieducar_audit ("date", "schema", "table", "context", "before", "after")
		values (now(), TG_TABLE_SCHEMA::text, TG_TABLE_NAME::text, audit_context(), to_json(old.*), to_json(new.*));

		return old;
	end if;

	if (TG_OP = 'INSERT') then
		insert into ieducar_audit ("date", "schema", "table", "context", "before", "after")
		values (now(), TG_TABLE_SCHEMA::text, TG_TABLE_NAME::text, audit_context(), null, to_json(new.*));

		return old;
	end if;

	return null;
end;
$$;


--
-- Name: audit_context(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.audit_context() RETURNS json
    LANGUAGE plpgsql
    AS $$
begin
	begin
		return current_setting('audit.context');
	exception when others then
		return json_build_object('user_id', 0, 'user_name', session_user);
	end;
end;
$$;


--
-- Name: audit_enabled(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.audit_enabled() RETURNS boolean
    LANGUAGE plpgsql
    AS $$
begin
	begin
		return current_setting('audit.enabled');
	exception when others then
		return true;
	end;
end;
$$;


--
-- Name: commacat_ignore_nulls(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.commacat_ignore_nulls(acc text, instr text) RETURNS text
    LANGUAGE plpgsql
    AS $$
  BEGIN
      IF acc IS NULL OR acc = '' THEN
        RETURN instr;
      ELSIF instr IS NULL OR instr = '' THEN
        RETURN acc || ' <br> ';
      ELSE
        RETURN acc || ' <br> ' || instr;
      END IF;
    END;
  $$;


--
-- Name: count_weekdays(date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.count_weekdays(date, date) RETURNS integer
    LANGUAGE plpgsql STABLE
    AS $_$
     DECLARE
      start_date alias for $1;
      end_date alias for $2;
      tmp_date date;
      tmp_dow integer;
      -- double precision returned from extract
      tot_dow integer;
     BEGIN
       tmp_date := start_date;
       tot_dow := 0;
       WHILE (tmp_date <= end_date) LOOP
         select into tmp_dow  cast(extract(dow from tmp_date) as integer);
         IF ((tmp_dow >= 2) and (tmp_dow <= 6)) THEN
           tot_dow := (tot_dow + 1);
         END IF;
         select into tmp_date (tmp_date + interval '1 day ');
       END LOOP;
       return tot_dow;

     END;
  $_$;


--
-- Name: data_para_extenso(date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.data_para_extenso(data date) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
	data_extenso varchar := '';
	mes_extenso varchar := '';
	dia integer := 0;
	mes integer := 0;
	ano integer := 0;
BEGIN

	dia := date_part('day', data)::integer;
	mes := date_part('month', data)::integer;
	ano := date_part('year', data)::integer;

	mes_extenso := case
				    when mes = 1  then 'Janeiro'
				    when mes = 2  then 'Fevereiro'
				    when mes = 3  then 'Março'
				    when mes = 4  then 'Abril'
				    when mes = 5  then 'Maio'
				    when mes = 6  then 'Junho'
				    when mes = 7  then 'Julho'
				    when mes = 8  then 'Agosto'
				    when mes = 9  then 'Setembro'
				    when mes = 10 then 'Outubro'
				    when mes = 11 then 'Novembro'
				    when mes = 12 then 'Dezembro'
				   else
					''
				   end;

	data_extenso := dia::varchar || ' de ' || mes_extenso || ' de ' || ano::varchar;

	return data_extenso;

END;
$$;


--
-- Name: f_unaccent(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.f_unaccent(text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$
            SELECT public.unaccent('public.unaccent', $1)
            $_$;


--
-- Name: fcn_upper(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fcn_upper(text) RETURNS text
    LANGUAGE plpgsql
    AS $_$
   DECLARE
    v_texto     ALIAS FOR $1;
    v_retorno   text := '';
   BEGIN
    IF v_texto IS NOT NULL THEN
     SELECT translate(upper(v_texto),'áéíóúýàèìòùãõâêîôûäëïöüç','ÁÉÍÓÚÝÀÈÌÒÙÃÕÂÊÎÔÛÄËÏÖÜÇ') INTO v_retorno;
    END IF;
    RETURN v_retorno;
   END;
  $_$;


--
-- Name: fcn_upper_nrm(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fcn_upper_nrm(text) RETURNS text
    LANGUAGE plpgsql
    AS $_$
   DECLARE
    v_texto     ALIAS FOR $1;
    v_retorno   text := '';
   BEGIN
    IF v_texto IS NOT NULL THEN
     SELECT translate(upper(v_texto),'áéíóúýàèìòùãõâêîôûäëïöüÿçÁÉÍÓÚÝÀÈÌÒÙÃÕÂÊÎÔÛÄËÏÖÜÇ','AEIOUYAEIOUAOAEIOUAEIOUYCAEIOUYAEIOUAOAEIOUAEIOUC') INTO v_retorno;
    END IF;
    RETURN v_retorno;
   END;
  $_$;


--
-- Name: formata_cpf(numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.formata_cpf(cpf numeric) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
    cpf_text text;
    cpf_formatado varchar(14);
BEGIN
  IF cpf IS NULL THEN
    RETURN '';
  END IF;

  -- Converte o CPF numérico para texto e preenche com zeros à esquerda
  cpf_text := lpad(TRIM(TO_CHAR(cpf, 'FM99999999999')), 11, '0');

  cpf_formatado := SUBSTR(cpf_text, 1, 3) || '.' ||
                   SUBSTR(cpf_text, 4, 3) || '.' ||
                   SUBSTR(cpf_text, 7, 3) || '-' ||
                   SUBSTR(cpf_text, 10, 2);

  RETURN cpf_formatado;
END;
$$;


--
-- Name: isnumeric(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.isnumeric(text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
  DECLARE x NUMERIC;
    BEGIN
        x = $1::NUMERIC;
        RETURN TRUE;
    EXCEPTION WHEN others THEN
        RETURN FALSE;
    END;
  $_$;


--
-- Name: retira_data_cancel_matricula_fun(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.retira_data_cancel_matricula_fun() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN

  UPDATE pmieducar.matricula
  SET    data_cancel = NULL
  WHERE  cod_matricula = new.cod_matricula
  AND    data_cancel IS DISTINCT FROM NULL
  AND    aprovado = 3
  AND (SELECT 1 FROM pmieducar.transferencia_solicitacao WHERE ativo = 1 AND ref_cod_matricula_saida = new.cod_matricula limit 1) is null;

  RETURN NULL;
  END
  $$;


--
-- Name: update_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
            BEGIN
                NEW.updated_at = now();
                RETURN NEW;
            END;
            $$;


--
-- Name: verifica_existe_matricula_posterior_mesma_turma(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.verifica_existe_matricula_posterior_mesma_turma(cod_matricula integer, cod_turma integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
                      DECLARE existe_matricula boolean;

                      BEGIN
                        existe_matricula := EXISTS (SELECT *
                                                      FROM pmieducar.matricula_turma mt
                                                     INNER JOIN pmieducar.matricula m ON (m.cod_matricula = mt.ref_cod_matricula)
                                                     INNER JOIN pmieducar.matricula m2 ON (m2.cod_matricula = m.cod_matricula)
                                                     INNER JOIN pmieducar.matricula_turma mt2 ON (mt2.ref_cod_matricula = m.cod_matricula
                                                                                                  AND mt2.ref_cod_turma = cod_turma)
                                                     WHERE mt.ref_cod_turma = mt2.ref_cod_turma
                                                       AND mt.ref_cod_matricula <> mt2.ref_cod_matricula
                                                       AND m.ref_cod_aluno = m2.ref_cod_aluno
                                                       AND mt.data_enturmacao > mt2.data_enturmacao
                                                       AND m.ativo = 1
                                                       AND m2.ativo = 1);

                        RETURN existe_matricula;
                      END;
                      $$;


--
-- Name: verifica_existe_matricula_posterior_mesma_turma(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.verifica_existe_matricula_posterior_mesma_turma(cod_matricula integer, cod_turma integer, sequencial integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$

      DECLARE existe_matricula boolean;

      BEGIN
        existe_matricula := EXISTS (SELECT *
                                      FROM pmieducar.matricula_turma mt
                                     INNER JOIN pmieducar.matricula m ON (m.cod_matricula = mt.ref_cod_matricula)
                                     INNER JOIN pmieducar.matricula m2 ON (m2.cod_matricula = cod_matricula)
                                     INNER JOIN pmieducar.matricula_turma mt2 ON (mt2.ref_cod_matricula = cod_matricula
                                                                                  AND mt2.ref_cod_turma = cod_turma
                                                                                  AND mt2.sequencial = sequencial)
                                     WHERE mt.ref_cod_turma = mt2.ref_cod_turma
                                       AND mt.ref_cod_matricula <> mt2.ref_cod_matricula
                                       AND m.ref_cod_aluno = m2.ref_cod_aluno
                                       AND mt.data_enturmacao > mt2.data_enturmacao);

        RETURN existe_matricula;
      END;

      $$;


--
-- Name: when_deleted_cadastro_deficiencia(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.when_deleted_cadastro_deficiencia() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
            BEGIN
                INSERT INTO cadastro.deficiencia_excluidos (cod_deficiencia, nm_deficiencia, deficiencia_educacenso, desconsidera_regra_diferenciada, updated_at, deleted_at) VALUES (OLD.cod_deficiencia, OLD.nm_deficiencia, OLD.deficiencia_educacenso, OLD.desconsidera_regra_diferenciada, NOW(), NOW());
                RETURN OLD;
            END;
            $$;


--
-- Name: when_deleted_modules_area_conhecimento(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.when_deleted_modules_area_conhecimento() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
            BEGIN
                INSERT INTO modules.area_conhecimento_excluidos (id, instituicao_id, nome, secao, ordenamento_ac, agrupar_descritores, updated_at, deleted_at) VALUES (OLD.id, OLD.instituicao_id, OLD.nome, OLD.secao, OLD.ordenamento_ac, OLD.agrupar_descritores, NOW(), NOW());
                RETURN OLD;
            END;
            $$;


--
-- Name: when_deleted_modules_componente_curricular_ano_escolar(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.when_deleted_modules_componente_curricular_ano_escolar() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
            BEGIN
                INSERT INTO modules.componente_curricular_ano_escolar_excluidos (componente_curricular_id, ano_escolar_id, carga_horaria, tipo_nota, anos_letivos, updated_at, deleted_at) VALUES (OLD.componente_curricular_id, OLD.ano_escolar_id, OLD.carga_horaria, OLD.tipo_nota, OLD.anos_letivos, NOW(), NOW());
                RETURN OLD;
            END;
            $$;


--
-- Name: when_deleted_modules_componente_curricular_turma(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.when_deleted_modules_componente_curricular_turma() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
            BEGIN
                INSERT INTO modules.componente_curricular_turma_excluidos (componente_curricular_id, ano_escolar_id, escola_id, turma_id, carga_horaria, docente_vinculado, etapas_especificas, etapas_utilizadas, updated_at, deleted_at) VALUES (OLD.componente_curricular_id, OLD.ano_escolar_id, OLD.escola_id, OLD.turma_id, OLD.carga_horaria, OLD.docente_vinculado, OLD.etapas_especificas, OLD.etapas_utilizadas, NOW(), NOW());
                RETURN OLD;
            END;
            $$;


--
-- Name: when_deleted_modules_professor_turma(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.when_deleted_modules_professor_turma() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
            BEGIN
                INSERT INTO modules.professor_turma_excluidos (id, ano, instituicao_id, turma_id, servidor_id, funcao_exercida, tipo_vinculo, permite_lancar_faltas_componente, turno_id, updated_at, deleted_at) VALUES (OLD.id, OLD.ano, OLD.instituicao_id, OLD.turma_id, OLD.servidor_id, OLD.funcao_exercida, OLD.tipo_vinculo, OLD.permite_lancar_faltas_componente, OLD.turno_id, NOW(), NOW());
                RETURN OLD;
            END;
            $$;


--
-- Name: when_deleted_modules_regra_avaliacao_recuperacao(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.when_deleted_modules_regra_avaliacao_recuperacao() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
            BEGIN
                INSERT INTO modules.regra_avaliacao_recuperacao_excluidos (id, regra_avaliacao_id, descricao, etapas_recuperadas, substitui_menor_nota, media, nota_maxima, updated_at, deleted_at) VALUES (OLD.id, OLD.regra_avaliacao_id, OLD.descricao, OLD.etapas_recuperadas, OLD.substitui_menor_nota, OLD.media, OLD.nota_maxima, NOW(), NOW());
                RETURN OLD;
            END;
            $$;


--
-- Name: when_deleted_modules_regra_avaliacao_serie_ano(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.when_deleted_modules_regra_avaliacao_serie_ano() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
            BEGIN
                INSERT INTO modules.regra_avaliacao_serie_ano_excluidos (serie_id, regra_avaliacao_id, regra_avaliacao_diferenciada_id, ano_letivo, updated_at, deleted_at) VALUES (OLD.serie_id, OLD.regra_avaliacao_id, OLD.regra_avaliacao_diferenciada_id, OLD.ano_letivo, NOW(), NOW());
                RETURN OLD;
            END;
            $$;


--
-- Name: when_deleted_pmieducar_aluno(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.when_deleted_pmieducar_aluno() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
            BEGIN
                INSERT INTO pmieducar.aluno_excluidos (cod_aluno, ref_idpes, updated_at, deleted_at) VALUES (OLD.cod_aluno, OLD.ref_idpes, NOW(), NOW());
                RETURN OLD;
            END;
            $$;


--
-- Name: when_deleted_pmieducar_disciplina_dependencia(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.when_deleted_pmieducar_disciplina_dependencia() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
            BEGIN
                INSERT INTO pmieducar.disciplina_dependencia_excluidos (cod_disciplina_dependencia, ref_cod_matricula, ref_cod_disciplina, ref_cod_escola, ref_cod_serie, observacao, updated_at, deleted_at) VALUES (OLD.cod_disciplina_dependencia, OLD.ref_cod_matricula, OLD.ref_cod_disciplina, OLD.ref_cod_escola, OLD.ref_cod_serie, OLD.observacao, NOW(), NOW());
                RETURN OLD;
            END;
            $$;


--
-- Name: when_deleted_pmieducar_dispensa_disciplina(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.when_deleted_pmieducar_dispensa_disciplina() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
            BEGIN
                INSERT INTO pmieducar.dispensa_disciplina_excluidos (cod_dispensa, ref_cod_matricula, ref_cod_disciplina, ref_cod_escola, ref_cod_serie, ref_usuario_exc, ref_usuario_cad, ref_cod_tipo_dispensa, data_cadastro, data_exclusao, ativo, observacao, updated_at, deleted_at) VALUES (OLD.cod_dispensa, OLD.ref_cod_matricula, OLD.ref_cod_disciplina, OLD.ref_cod_escola, OLD.ref_cod_serie, OLD.ref_usuario_exc, OLD.ref_usuario_cad, OLD.ref_cod_tipo_dispensa, OLD.data_cadastro, OLD.data_exclusao, OLD.ativo, OLD.observacao, NOW(), NOW());
                RETURN OLD;
            END;
            $$;


--
-- Name: when_deleted_pmieducar_escola_serie_disciplina(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.when_deleted_pmieducar_escola_serie_disciplina() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
            BEGIN
                INSERT INTO pmieducar.escola_serie_disciplina_excluidos (ref_ref_cod_serie, ref_ref_cod_escola, ref_cod_disciplina, ativo, carga_horaria, etapas_especificas, etapas_utilizadas, anos_letivos, updated_at, deleted_at) VALUES (OLD.ref_ref_cod_serie, OLD.ref_ref_cod_escola, OLD.ref_cod_disciplina, OLD.ativo, OLD.carga_horaria, OLD.etapas_especificas, OLD.etapas_utilizadas, OLD.anos_letivos, NOW(), NOW());
                RETURN OLD;
            END;
            $$;


--
-- Name: count_weekdays(date, date); Type: FUNCTION; Schema: relatorio; Owner: -
--

CREATE FUNCTION relatorio.count_weekdays(start_date date, end_date date) RETURNS integer
    LANGUAGE plpgsql
    AS $$
                        DECLARE
                          tmp_date date;
                          tmp_dow integer;
                          -- double precision returned from extract
                          tot_dow integer;
                        BEGIN
                          tmp_date := start_date;
                          tot_dow := 0;

                          WHILE (tmp_date <= end_date) LOOP
                            SELECT INTO tmp_dow cast(extract(dow
                              FROM tmp_date) AS integer);

                            IF ((tmp_dow >= 2) AND (tmp_dow <= 6)) THEN
                              tot_dow := (tot_dow + 1);
                            END IF;

                            SELECT INTO tmp_date (tmp_date + interval '1 DAY ');

                          END LOOP;

                          RETURN tot_dow;
                        END; $$;


--
-- Name: exibe_aluno_conforme_parametro_alunos_diferenciados(integer, integer); Type: FUNCTION; Schema: relatorio; Owner: -
--

CREATE FUNCTION relatorio.exibe_aluno_conforme_parametro_alunos_diferenciados(codigo_aluno integer, alunos_diferenciados integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    possui_deficiencia boolean;
BEGIN

    possui_deficiencia := EXISTS
        (SELECT 1
         FROM cadastro.fisica_deficiencia fd
                  JOIN pmieducar.aluno a ON fd.ref_idpes = a.ref_idpes
                  JOIN cadastro.deficiencia d ON d.cod_deficiencia = fd.ref_cod_deficiencia
         WHERE a.cod_aluno = codigo_aluno
           AND d.desconsidera_regra_diferenciada = false
         LIMIT 1
        );

    CASE alunos_diferenciados
        WHEN 1 THEN RETURN possui_deficiencia = false;
        WHEN 2 THEN RETURN possui_deficiencia = true;
        ELSE RETURN true;
        END CASE;

END; $$;


--
-- Name: get_ddd_escola(integer); Type: FUNCTION; Schema: relatorio; Owner: -
--

CREATE FUNCTION relatorio.get_ddd_escola(integer) RETURNS numeric
    LANGUAGE sql
    AS $_$
SELECT COALESCE(
           (SELECT min(fone_pessoa.ddd)
            FROM cadastro.fone_pessoa, cadastro.juridica
            WHERE juridica.idpes = fone_pessoa.idpes
              AND juridica.idpes =
                  (SELECT idpes
                   FROM cadastro.pessoa
                            INNER JOIN pmieducar.escola ON escola.ref_idpes = pessoa.idpes
                   WHERE cod_escola = $1)),
           (SELECT min(ddd_telefone)
            FROM pmieducar.escola_complemento
            WHERE ref_cod_escola = $1)); $_$;


--
-- Name: get_mae_aluno(integer); Type: FUNCTION; Schema: relatorio; Owner: -
--

CREATE FUNCTION relatorio.get_mae_aluno(integer) RETURNS character varying
    LANGUAGE sql
    AS $_$
SELECT coalesce(
           (SELECT nome
            FROM cadastro.pessoa
            WHERE idpes = fisica.idpes_mae), (aluno.nm_mae))
FROM pmieducar.aluno
         INNER JOIN cadastro.fisica ON fisica.idpes = aluno.ref_idpes
WHERE aluno.ativo = 1
  AND aluno.cod_aluno = $1; $_$;


--
-- Name: get_max_sequencial_matricula(integer); Type: FUNCTION; Schema: relatorio; Owner: -
--

CREATE FUNCTION relatorio.get_max_sequencial_matricula(integer) RETURNS integer
    LANGUAGE sql
    AS $_$
SELECT MAX(matricula_turma.sequencial)
FROM pmieducar.matricula_turma
         INNER JOIN pmieducar.matricula ON (matricula.cod_matricula = matricula_turma.ref_cod_matricula)
         INNER JOIN relatorio.view_situacao ON (view_situacao.cod_matricula = matricula.cod_matricula
    AND view_situacao.cod_turma = matricula_turma.ref_cod_turma
    AND view_situacao.sequencial = matricula_turma.sequencial)
WHERE ref_cod_matricula = $1;
$_$;


--
-- Name: get_media_geral_turma(integer, integer); Type: FUNCTION; Schema: relatorio; Owner: -
--

CREATE FUNCTION relatorio.get_media_geral_turma(turma_i integer, componente_i integer) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN (SELECT avg(nota_componente_curricular.nota)
            FROM modules.nota_componente_curricular,
                 modules.nota_aluno,
                 pmieducar.matricula m,
                 pmieducar.matricula_turma mt
            WHERE nota_componente_curricular.nota_aluno_id = nota_aluno.id
              AND nota_componente_curricular.componente_curricular_id = componente_i
              AND nota_aluno.matricula_id = m.cod_matricula
              AND m.cod_matricula = mt.ref_cod_matricula
              AND mt.ativo = 1
              AND m.ativo = 1
              AND mt.ref_cod_turma = turma_i);
END; $$;


--
-- Name: get_media_turma(integer, integer, integer); Type: FUNCTION; Schema: relatorio; Owner: -
--

CREATE FUNCTION relatorio.get_media_turma(turma_i integer, componente_i integer, etapa_i integer) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN (SELECT avg(nota_componente_curricular.nota)
            FROM modules.nota_componente_curricular,
                 modules.nota_aluno,
                 pmieducar.matricula m,
                 pmieducar.matricula_turma mt
            WHERE nota_componente_curricular.nota_aluno_id = nota_aluno.id
              AND nota_componente_curricular.componente_curricular_id = componente_i
              AND nota_aluno.matricula_id = m.cod_matricula
              AND m.cod_matricula = mt.ref_cod_matricula
              AND mt.ativo = 1
              AND m.ativo = 1
              AND mt.ref_cod_turma = turma_i
              AND nota_componente_curricular.etapa = etapa_i::varchar);
END; $$;


--
-- Name: get_nacionalidade(numeric); Type: FUNCTION; Schema: relatorio; Owner: -
--

CREATE FUNCTION relatorio.get_nacionalidade(nacionalidade_id numeric) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
BEGIN RETURN
    (SELECT CASE
                WHEN nacionalidade_id = 1
                    THEN 'Brasileira'
                WHEN nacionalidade_id = 2
                    THEN 'Naturalizado Brasileiro'
                WHEN nacionalidade_id = 3
                    THEN 'Estrangeira'
                END);
END;
$$;


--
-- Name: get_nome_escola(integer); Type: FUNCTION; Schema: relatorio; Owner: -
--

CREATE FUNCTION relatorio.get_nome_escola(integer) RETURNS character varying
    LANGUAGE sql
    AS $_$SELECT COALESCE(
               (SELECT COALESCE (fcn_upper(ps.nome),fcn_upper(juridica.fantasia))
            FROM cadastro.pessoa ps, cadastro.juridica
           WHERE escola.ref_idpes = juridica.idpes
             AND juridica.idpes = ps.idpes
             AND ps.idpes = escola.ref_idpes),
               (SELECT nm_escola
            FROM pmieducar.escola_complemento
           WHERE ref_cod_escola = escola.cod_escola))
          FROM pmieducar.escola
         WHERE escola.cod_escola = $1;$_$;


--
-- Name: get_nome_modulo(integer); Type: FUNCTION; Schema: relatorio; Owner: -
--

CREATE FUNCTION relatorio.get_nome_modulo(integer) RETURNS character varying
    LANGUAGE sql
    AS $_$
SELECT MIN(modulo.nm_tipo)
FROM pmieducar.turma
         INNER JOIN pmieducar.curso ON (curso.cod_curso = turma.ref_cod_curso)
         LEFT JOIN pmieducar.ano_letivo_modulo ON (ano_letivo_modulo.ref_ano = turma.ano
    AND ano_letivo_modulo.ref_ref_cod_escola = turma.ref_ref_cod_escola
    AND curso.padrao_ano_escolar = 1)
         LEFT JOIN pmieducar.turma_modulo ON (turma_modulo.ref_cod_turma = turma.cod_turma
    AND curso.padrao_ano_escolar = 0)
         INNER JOIN pmieducar.modulo ON (CASE
                                             WHEN curso.padrao_ano_escolar = 1 THEN modulo.cod_modulo = ano_letivo_modulo.ref_cod_modulo
                                             ELSE modulo.cod_modulo = turma_modulo.ref_cod_modulo
    END)
WHERE turma.cod_turma = $1;$_$;


--
-- Name: get_nota_exame(integer, integer); Type: FUNCTION; Schema: relatorio; Owner: -
--

CREATE FUNCTION relatorio.get_nota_exame(integer, integer) RETURNS character varying
    LANGUAGE sql
    AS $_$
(SELECT CASE WHEN nota_componente_curricular.nota_arredondada = '10' THEN '10,0' WHEN char_length(nota_componente_curricular.nota_arredondada) = 1 THEN replace(nota_componente_curricular.nota_arredondada,'.',',') || ',0' ELSE replace(nota_componente_curricular.nota_arredondada,'.',',') END
 FROM modules.nota_componente_curricular, modules.nota_aluno
 WHERE nota_componente_curricular.componente_curricular_id = $1
   AND nota_componente_curricular.etapa = 'Rc'
   AND nota_aluno.id = nota_componente_curricular.nota_aluno_id
   AND nota_aluno.matricula_id = $2); $_$;


--
-- Name: get_pai_aluno(integer); Type: FUNCTION; Schema: relatorio; Owner: -
--

CREATE FUNCTION relatorio.get_pai_aluno(integer) RETURNS character varying
    LANGUAGE sql
    AS $_$
SELECT coalesce(
           (SELECT nome
            FROM cadastro.pessoa
            WHERE idpes = fisica.idpes_pai), (aluno.nm_pai))
FROM pmieducar.aluno
         INNER JOIN cadastro.fisica ON fisica.idpes = aluno.ref_idpes
WHERE aluno.ativo = 1
  AND aluno.cod_aluno = $1; $_$;


--
-- Name: get_qtde_alunos(integer, integer); Type: FUNCTION; Schema: relatorio; Owner: -
--

CREATE FUNCTION relatorio.get_qtde_alunos(integer, integer) RETURNS bigint
    LANGUAGE sql
    AS $_$
SELECT COUNT(*)
FROM pmieducar.matricula
WHERE matricula.ativo = 1
  AND (CASE WHEN 0 = $1 THEN TRUE ELSE matricula.ano = $1 END)
  AND (CASE WHEN 0 = $2 THEN TRUE ELSE matricula.ref_ref_cod_escola = $2 END); $_$;


--
-- Name: get_qtde_modulo(integer); Type: FUNCTION; Schema: relatorio; Owner: -
--

CREATE FUNCTION relatorio.get_qtde_modulo(integer) RETURNS integer
    LANGUAGE sql
    AS $_$
SELECT COUNT(modulo.nm_tipo)::integer AS qtde
FROM pmieducar.turma
         INNER JOIN pmieducar.curso ON (curso.cod_curso = turma.ref_cod_curso)
         LEFT JOIN pmieducar.ano_letivo_modulo ON (ano_letivo_modulo.ref_ano = turma.ano
    AND ano_letivo_modulo.ref_ref_cod_escola = turma.ref_ref_cod_escola
    AND curso.padrao_ano_escolar = 1)
         LEFT JOIN pmieducar.turma_modulo ON (turma_modulo.ref_cod_turma = turma.cod_turma
    AND curso.padrao_ano_escolar = 0)
         INNER JOIN pmieducar.modulo ON (CASE
                                             WHEN curso.padrao_ano_escolar = 1 THEN modulo.cod_modulo = ano_letivo_modulo.ref_cod_modulo
                                             ELSE modulo.cod_modulo = turma_modulo.ref_cod_modulo
    END)
WHERE turma.cod_turma = $1;$_$;


--
-- Name: get_situacao_componente(numeric); Type: FUNCTION; Schema: relatorio; Owner: -
--

CREATE FUNCTION relatorio.get_situacao_componente(cod_situacao numeric) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
    texto_situacao varchar(30) := '';
BEGIN
    texto_situacao := (CASE
                           WHEN cod_situacao = 1 THEN 'Aprovado'
                           WHEN cod_situacao = 2 THEN 'Retido'
                           WHEN cod_situacao = 3 THEN 'Cursando'
                           WHEN cod_situacao = 4 THEN 'Transferido'
                           WHEN cod_situacao = 5 THEN 'Reclassificado'
                           WHEN cod_situacao = 6 THEN 'Deixou de Frequentar'
                           WHEN cod_situacao = 7 THEN 'Em exame'
                           WHEN cod_situacao = 8 THEN 'Aprovado após exame'
                           WHEN cod_situacao = 9 THEN 'Retido por falta'
                           WHEN cod_situacao = 10 THEN 'Aprovado sem exame'
                           WHEN cod_situacao = 11 THEN 'Pré-matrícula'
                           WHEN cod_situacao = 12 THEN 'Aprovado com dependência'
                           WHEN cod_situacao = 13 THEN 'Aprovado pelo conselho'
                           WHEN cod_situacao = 14 THEN 'Rep. Faltas'
                           WHEN cod_situacao = 15 THEN 'Falecido'
                           ELSE '' END);
    RETURN texto_situacao;
END;
$$;


--
-- Name: get_situacao_historico(integer); Type: FUNCTION; Schema: relatorio; Owner: -
--

CREATE FUNCTION relatorio.get_situacao_historico(situacao integer) RETURNS character varying
    LANGUAGE sql
    AS $$
SELECT CASE
           WHEN situacao = 1 THEN 'Aprovado'::character varying
           WHEN situacao = 2 THEN 'Reprovado'::character varying
           WHEN situacao = 3 THEN 'Cursando'::character varying
           WHEN situacao = 4 THEN 'Transferido'::character varying
           WHEN situacao = 5 THEN 'Reclassificado'::character varying
           WHEN situacao = 6 THEN 'Deixou de Frequentar'::character varying
           WHEN situacao = 12 THEN 'Ap. Depen.'::character varying
           WHEN situacao = 13 THEN 'Aprovado conselho'::character varying
           WHEN situacao = 14 THEN 'Reprovado por faltas'::character varying
           ELSE ''::character varying
           END AS situacao; $$;


--
-- Name: get_situacao_historico_abreviado(integer); Type: FUNCTION; Schema: relatorio; Owner: -
--

CREATE FUNCTION relatorio.get_situacao_historico_abreviado(integer) RETURNS character varying
    LANGUAGE sql
    AS $_$
SELECT CASE
           WHEN $1 = 1 THEN 'Apr'::character varying
           WHEN $1 = 2 THEN 'Rep'::character varying
           WHEN $1 = 3 THEN 'Cur'::character varying
           WHEN $1 = 4 THEN 'Trs'::character varying
           WHEN $1 = 5 THEN 'Recl'::character varying
           WHEN $1 = 6 THEN 'DeFr'::character varying
           WHEN $1 = 12 THEN 'ApDp'::character varying
           WHEN $1 = 13 THEN 'ApCo'::character varying
           WHEN $1 = 14 THEN 'RpFt'::character varying
           ELSE ''::character varying
           END AS situacao; $_$;


--
-- Name: get_telefone_escola(integer); Type: FUNCTION; Schema: relatorio; Owner: -
--

CREATE FUNCTION relatorio.get_telefone_escola(integer) RETURNS character varying
    LANGUAGE sql
    AS $_$
SELECT COALESCE(
           (SELECT min(to_char(fone_pessoa.fone, '99999-9999'))
            FROM cadastro.fone_pessoa, cadastro.juridica
            WHERE juridica.idpes = fone_pessoa.idpes
              AND juridica.idpes =
                  (SELECT idpes
                   FROM cadastro.pessoa
                            INNER JOIN pmieducar.escola ON escola.ref_idpes = pessoa.idpes
                   WHERE cod_escola = $1)),
           (SELECT min(to_char(telefone, '99999-9999'))
            FROM pmieducar.escola_complemento
            WHERE escola_complemento.ref_cod_escola = $1)); $_$;


--
-- Name: get_texto_sem_caracter_especial(character varying); Type: FUNCTION; Schema: relatorio; Owner: -
--

CREATE FUNCTION relatorio.get_texto_sem_caracter_especial(character varying) RETURNS character varying
    LANGUAGE sql
    AS $_$SELECT translate(public.fcn_upper($1),
                       'åáàãâäéèêëíìîïóòõôöúùüûçÿýñÅÁÀÃÂÄÉÈÊËÍÌÎÏÓÒÕÔÖÚÙÛÜÇÝÑ',
                       'aaaaaaeeeeiiiiooooouuuucyynAAAAAAEEEEIIIIOOOOOUUUUCYN');$_$;


--
-- Name: get_total_falta_componente(integer, integer); Type: FUNCTION; Schema: relatorio; Owner: -
--

CREATE FUNCTION relatorio.get_total_falta_componente(matricula_i integer, componente_i integer) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN (SELECT sum(falta_componente_curricular.quantidade)
            FROM modules.falta_componente_curricular,
                 modules.falta_aluno
            WHERE falta_componente_curricular.falta_aluno_id = falta_aluno.id AND
                    falta_aluno.matricula_id = matricula_i AND
                    falta_componente_curricular.etapa in ('1','2','3','4') AND
                    falta_componente_curricular.componente_curricular_id = componente_i AND
                    falta_aluno.tipo_falta = 2);
END; $$;


--
-- Name: get_total_faltas(integer); Type: FUNCTION; Schema: relatorio; Owner: -
--

CREATE FUNCTION relatorio.get_total_faltas(matricula_i integer) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN (SELECT sum(falta_geral.quantidade)
            FROM modules.falta_geral,
                 modules.falta_aluno
            WHERE falta_geral.falta_aluno_id = falta_aluno.id AND
                    falta_aluno.matricula_id = matricula_i AND
                    falta_aluno.tipo_falta = 1 AND
                    falta_geral.etapa in ('1','2','3','4'));
END; $$;


--
-- Name: get_total_geral_falta_componente(integer); Type: FUNCTION; Schema: relatorio; Owner: -
--

CREATE FUNCTION relatorio.get_total_geral_falta_componente(matricula_i integer) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN (SELECT sum(falta_componente_curricular.quantidade)
            FROM modules.falta_componente_curricular,
                 modules.falta_aluno
            WHERE falta_componente_curricular.falta_aluno_id = falta_aluno.id AND
                    falta_aluno.matricula_id = matricula_i AND
                    falta_componente_curricular.etapa in ('1','2','3','4') AND
                    falta_aluno.tipo_falta = 2);
END; $$;


--
-- Name: get_valor_campo_auditoria(character varying, character varying, character varying); Type: FUNCTION; Schema: relatorio; Owner: -
--

CREATE FUNCTION relatorio.get_valor_campo_auditoria(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE sql
    AS $_$
SELECT CASE
           WHEN $2 = '' THEN substr($3, strpos($3, $1||':')+char_length($1)+1, ((strpos($3, '}')) - (strpos($3, $1)+char_length($1)+1)))
           ELSE substr($3, strpos($3, $1||':')+char_length($1)+1, ((strpos($3, $2||':')-1) - (strpos($3, $1)+char_length($1)+1)))
           END AS nome_instituicao;$_$;


--
-- Name: prioridade_historico(numeric); Type: FUNCTION; Schema: relatorio; Owner: -
--

CREATE FUNCTION relatorio.prioridade_historico(situacao numeric) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
    prioridade NUMERIC := 0;
BEGIN
    prioridade := (CASE
                       WHEN situacao = 1  THEN 1
                       WHEN situacao = 12 THEN 1
                       WHEN situacao = 13 THEN 1
                       WHEN situacao = 2  THEN 2
                       WHEN situacao = 14 THEN 2
                       WHEN situacao = 3  THEN 3
                       WHEN situacao = 4  THEN 4
                       WHEN situacao = 6  THEN 4
                       ELSE 5 END);
    RETURN prioridade;
END;
$$;


--
-- Name: textcat_all(text); Type: AGGREGATE; Schema: public; Owner: -
--

CREATE AGGREGATE public.textcat_all(text) (
    SFUNC = public.commacat_ignore_nulls,
    STYPE = text,
    INITCOND = ''
);


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: codigo_cartorio_inep; Type: TABLE; Schema: cadastro; Owner: -
--

CREATE TABLE cadastro.codigo_cartorio_inep (
    id integer NOT NULL,
    id_cartorio integer NOT NULL,
    descricao character varying,
    cod_serventia integer,
    cod_municipio integer,
    ref_sigla_uf character varying(3)
);


--
-- Name: codigo_cartorio_inep_id_seq; Type: SEQUENCE; Schema: cadastro; Owner: -
--

CREATE SEQUENCE cadastro.codigo_cartorio_inep_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: codigo_cartorio_inep_id_seq; Type: SEQUENCE OWNED BY; Schema: cadastro; Owner: -
--

ALTER SEQUENCE cadastro.codigo_cartorio_inep_id_seq OWNED BY cadastro.codigo_cartorio_inep.id;


--
-- Name: deficiencia_cod_deficiencia_seq; Type: SEQUENCE; Schema: cadastro; Owner: -
--

CREATE SEQUENCE cadastro.deficiencia_cod_deficiencia_seq
    START WITH 15
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: deficiencia; Type: TABLE; Schema: cadastro; Owner: -
--

CREATE TABLE cadastro.deficiencia (
    cod_deficiencia integer DEFAULT nextval('cadastro.deficiencia_cod_deficiencia_seq'::regclass) NOT NULL,
    nm_deficiencia character varying(70) NOT NULL,
    deficiencia_educacenso smallint,
    desconsidera_regra_diferenciada boolean DEFAULT false,
    updated_at timestamp without time zone DEFAULT now(),
    exigir_laudo_medico boolean DEFAULT true NOT NULL,
    deficiency_type_id smallint DEFAULT '1'::smallint NOT NULL,
    transtorno_educacenso smallint
);


--
-- Name: deficiencia_excluidos; Type: TABLE; Schema: cadastro; Owner: -
--

CREATE TABLE cadastro.deficiencia_excluidos (
    cod_deficiencia integer NOT NULL,
    nm_deficiencia character varying(191) NOT NULL,
    deficiencia_educacenso integer,
    desconsidera_regra_diferenciada boolean,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    deleted_at timestamp(0) without time zone
);


--
-- Name: documento; Type: TABLE; Schema: cadastro; Owner: -
--

CREATE TABLE cadastro.documento (
    idpes numeric(8,0) NOT NULL,
    rg character varying(25),
    data_exp_rg date,
    sigla_uf_exp_rg character(2),
    tipo_cert_civil numeric(2,0),
    num_termo numeric(8,0),
    num_livro character varying(8),
    num_folha numeric(4,0),
    data_emissao_cert_civil date,
    sigla_uf_cert_civil character(2),
    cartorio_cert_civil character varying(200),
    num_cart_trabalho numeric(9,0),
    serie_cart_trabalho numeric(5,0),
    data_emissao_cart_trabalho date,
    sigla_uf_cart_trabalho character(2),
    num_tit_eleitor numeric(13,0),
    zona_tit_eleitor numeric(4,0),
    secao_tit_eleitor numeric(4,0),
    idorg_exp_rg integer,
    idpes_rev numeric,
    data_rev timestamp without time zone,
    origem_gravacao character(1) NOT NULL,
    idpes_cad numeric,
    data_cad timestamp without time zone NOT NULL,
    operacao character(1) NOT NULL,
    certidao_nascimento character varying(50),
    cartorio_cert_civil_inep integer,
    certidao_casamento character varying(50),
    passaporte character varying(20),
    comprovante_residencia character varying(255),
    declaracao_trabalho_autonomo character varying,
    CONSTRAINT ck_documento_operacao CHECK (((operacao = 'I'::bpchar) OR (operacao = 'A'::bpchar) OR (operacao = 'E'::bpchar))),
    CONSTRAINT ck_documento_origem_gravacao CHECK (((origem_gravacao = 'M'::bpchar) OR (origem_gravacao = 'U'::bpchar) OR (origem_gravacao = 'C'::bpchar) OR (origem_gravacao = 'O'::bpchar))),
    CONSTRAINT ck_documento_tipo_cert CHECK (((tipo_cert_civil >= (91)::numeric) AND (tipo_cert_civil <= (92)::numeric)))
);


--
-- Name: endereco_externo; Type: VIEW; Schema: cadastro; Owner: -
--

CREATE VIEW cadastro.endereco_externo AS
 SELECT NULL::integer AS idpes,
    NULL::integer AS tipo,
    NULL::integer AS idtlog,
    NULL::character varying AS logradouro,
    NULL::character varying AS numero,
    NULL::character varying AS letra,
    NULL::character varying AS complemento,
    NULL::character varying AS bairro,
    NULL::character varying AS cep,
    NULL::character varying AS cidade,
    NULL::character varying AS sigla_uf,
    NULL::date AS reside_desde,
    NULL::integer AS idpes_rev,
    NULL::timestamp without time zone AS data_rev,
    NULL::bpchar AS origem_gravacao,
    NULL::integer AS idpes_cad,
    NULL::timestamp without time zone AS data_cad,
    NULL::bpchar AS operacao,
    NULL::character varying AS bloco,
    NULL::integer AS andar,
    NULL::integer AS apartamento,
    NULL::integer AS zona_localizacao;


--
-- Name: escolaridade; Type: TABLE; Schema: cadastro; Owner: -
--

CREATE TABLE cadastro.escolaridade (
    idesco numeric(2,0) NOT NULL,
    descricao character varying(60) NOT NULL,
    escolaridade smallint
);


--
-- Name: estado_civil; Type: TABLE; Schema: cadastro; Owner: -
--

CREATE TABLE cadastro.estado_civil (
    ideciv numeric(1,0) NOT NULL,
    descricao character varying(15) NOT NULL
);


--
-- Name: fisica; Type: TABLE; Schema: cadastro; Owner: -
--

CREATE TABLE cadastro.fisica (
    idpes numeric(8,0) NOT NULL,
    data_nasc date,
    sexo character(1),
    idpes_mae numeric(8,0),
    idpes_pai numeric(8,0),
    idpes_responsavel numeric(8,0),
    idesco numeric(2,0),
    ideciv numeric(1,0),
    idpes_con numeric(8,0),
    data_uniao date,
    data_obito date,
    nacionalidade numeric(1,0),
    idpais_estrangeiro numeric(3,0),
    data_chegada_brasil date,
    idmun_nascimento numeric(6,0),
    ultima_empresa character varying(150),
    nome_mae character varying(150),
    nome_pai character varying(150),
    nome_conjuge character varying(150),
    nome_responsavel character varying(150),
    justificativa_provisorio character varying(150),
    idpes_rev numeric,
    data_rev timestamp without time zone,
    origem_gravacao character(1) NOT NULL,
    idpes_cad numeric,
    data_cad timestamp without time zone NOT NULL,
    operacao character(1) NOT NULL,
    ref_cod_sistema integer,
    cpf numeric(11,0),
    ref_cod_religiao integer,
    nis_pis_pasep numeric(11,0),
    sus character varying(20),
    ocupacao character varying(255),
    empresa character varying(255),
    pessoa_contato character varying(255),
    renda_mensal numeric(10,2),
    data_admissao date,
    ddd_telefone_empresa numeric(3,0),
    telefone_empresa numeric(11,0),
    falecido boolean,
    ativo integer DEFAULT 1,
    ref_usuario_exc integer,
    data_exclusao timestamp without time zone,
    zona_localizacao_censo integer,
    tipo_trabalho integer,
    local_trabalho character varying,
    horario_inicial_trabalho time without time zone,
    horario_final_trabalho time without time zone,
    nome_social character varying(150),
    pais_residencia integer DEFAULT 76 NOT NULL,
    localizacao_diferenciada integer,
    observacao text,
    povo_indigena_educacenso_id bigint,
    CONSTRAINT ck_fisica_nacionalidade CHECK (((nacionalidade >= (1)::numeric) AND (nacionalidade <= (3)::numeric))),
    CONSTRAINT ck_fisica_operacao CHECK (((operacao = 'I'::bpchar) OR (operacao = 'A'::bpchar) OR (operacao = 'E'::bpchar))),
    CONSTRAINT ck_fisica_origem_gravacao CHECK (((origem_gravacao = 'M'::bpchar) OR (origem_gravacao = 'U'::bpchar) OR (origem_gravacao = 'C'::bpchar) OR (origem_gravacao = 'O'::bpchar))),
    CONSTRAINT ck_fisica_sexo CHECK (((sexo = 'M'::bpchar) OR (sexo = 'F'::bpchar)))
);


--
-- Name: fisica_deficiencia; Type: TABLE; Schema: cadastro; Owner: -
--

CREATE TABLE cadastro.fisica_deficiencia (
    ref_idpes integer NOT NULL,
    ref_cod_deficiencia integer NOT NULL
);


--
-- Name: fisica_foto; Type: TABLE; Schema: cadastro; Owner: -
--

CREATE TABLE cadastro.fisica_foto (
    idpes integer NOT NULL,
    caminho character varying(255),
    updated_at timestamp without time zone DEFAULT now()
);


--
-- Name: fisica_raca; Type: TABLE; Schema: cadastro; Owner: -
--

CREATE TABLE cadastro.fisica_raca (
    ref_idpes integer NOT NULL,
    ref_cod_raca integer NOT NULL
);


--
-- Name: fone_pessoa; Type: TABLE; Schema: cadastro; Owner: -
--

CREATE TABLE cadastro.fone_pessoa (
    idpes numeric(8,0) NOT NULL,
    tipo numeric(1,0) NOT NULL,
    ddd numeric(3,0) NOT NULL,
    fone numeric(11,0) NOT NULL,
    idpes_rev numeric,
    data_rev timestamp without time zone,
    origem_gravacao character(1) NOT NULL,
    idpes_cad numeric,
    data_cad timestamp without time zone NOT NULL,
    operacao character(1) NOT NULL,
    CONSTRAINT ck_fone_pessoa_operacao CHECK (((operacao = 'I'::bpchar) OR (operacao = 'A'::bpchar) OR (operacao = 'E'::bpchar))),
    CONSTRAINT ck_fone_pessoa_origem_gravacao CHECK (((origem_gravacao = 'M'::bpchar) OR (origem_gravacao = 'U'::bpchar) OR (origem_gravacao = 'C'::bpchar) OR (origem_gravacao = 'O'::bpchar))),
    CONSTRAINT ck_fone_pessoa_tipo CHECK (((tipo >= (1)::numeric) AND (tipo <= (4)::numeric)))
);


--
-- Name: juridica; Type: TABLE; Schema: cadastro; Owner: -
--

CREATE TABLE cadastro.juridica (
    idpes numeric(8,0) NOT NULL,
    cnpj numeric(14,0),
    insc_estadual numeric(20,0),
    idpes_rev numeric,
    data_rev timestamp without time zone,
    origem_gravacao character(1) NOT NULL,
    idpes_cad numeric,
    data_cad timestamp without time zone NOT NULL,
    operacao character(1) NOT NULL,
    fantasia character varying(255),
    capital_social character varying(255),
    CONSTRAINT ck_juridica_operacao CHECK (((operacao = 'I'::bpchar) OR (operacao = 'A'::bpchar) OR (operacao = 'E'::bpchar))),
    CONSTRAINT ck_juridica_origem_gravacao CHECK (((origem_gravacao = 'M'::bpchar) OR (origem_gravacao = 'U'::bpchar) OR (origem_gravacao = 'C'::bpchar) OR (origem_gravacao = 'O'::bpchar)))
);


--
-- Name: orgao_emissor_rg_idorg_rg_seq; Type: SEQUENCE; Schema: cadastro; Owner: -
--

CREATE SEQUENCE cadastro.orgao_emissor_rg_idorg_rg_seq
    START WITH 30
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: orgao_emissor_rg; Type: TABLE; Schema: cadastro; Owner: -
--

CREATE TABLE cadastro.orgao_emissor_rg (
    idorg_rg integer DEFAULT nextval('cadastro.orgao_emissor_rg_idorg_rg_seq'::regclass) NOT NULL,
    sigla character varying(20) NOT NULL,
    descricao character varying(60) NOT NULL,
    situacao character(1) NOT NULL,
    codigo_educacenso integer,
    CONSTRAINT ck_orgao_emissor_rg_situacao CHECK (((situacao = 'A'::bpchar) OR (situacao = 'I'::bpchar)))
);


--
-- Name: pessoa; Type: TABLE; Schema: cadastro; Owner: -
--

CREATE TABLE cadastro.pessoa (
    idpes numeric(8,0) DEFAULT nextval(('cadastro.seq_pessoa'::text)::regclass) NOT NULL,
    nome character varying(150) NOT NULL,
    idpes_cad numeric(8,0),
    data_cad timestamp without time zone NOT NULL,
    url character varying(60),
    tipo character(1) NOT NULL,
    idpes_rev numeric(8,0),
    data_rev timestamp without time zone,
    email character varying(100),
    situacao character(1) NOT NULL,
    origem_gravacao character(1) NOT NULL,
    operacao character(1) NOT NULL,
    slug character varying(191),
    CONSTRAINT ck_pessoa_operacao CHECK (((operacao = 'I'::bpchar) OR (operacao = 'A'::bpchar) OR (operacao = 'E'::bpchar))),
    CONSTRAINT ck_pessoa_origem_gravacao CHECK (((origem_gravacao = 'M'::bpchar) OR (origem_gravacao = 'U'::bpchar) OR (origem_gravacao = 'C'::bpchar) OR (origem_gravacao = 'O'::bpchar))),
    CONSTRAINT ck_pessoa_situacao CHECK (((situacao = 'A'::bpchar) OR (situacao = 'I'::bpchar) OR (situacao = 'P'::bpchar))),
    CONSTRAINT ck_pessoa_tipo CHECK (((tipo = 'F'::bpchar) OR (tipo = 'J'::bpchar)))
);


--
-- Name: raca_cod_raca_seq; Type: SEQUENCE; Schema: cadastro; Owner: -
--

CREATE SEQUENCE cadastro.raca_cod_raca_seq
    START WITH 1
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: raca; Type: TABLE; Schema: cadastro; Owner: -
--

CREATE TABLE cadastro.raca (
    cod_raca integer DEFAULT nextval('cadastro.raca_cod_raca_seq'::regclass) NOT NULL,
    idpes_exc integer,
    idpes_cad integer NOT NULL,
    nm_raca character varying(50) NOT NULL,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo boolean DEFAULT false,
    raca_educacenso smallint
);


--
-- Name: seq_pessoa; Type: SEQUENCE; Schema: cadastro; Owner: -
--

CREATE SEQUENCE cadastro.seq_pessoa
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: v_fone_pessoa; Type: VIEW; Schema: cadastro; Owner: -
--

CREATE VIEW cadastro.v_fone_pessoa AS
 SELECT DISTINCT idpes,
    ( SELECT t1.ddd
           FROM cadastro.fone_pessoa t1
          WHERE ((t1.tipo = (1)::numeric) AND (t.idpes = t1.idpes))) AS ddd_1,
    ( SELECT t1.fone
           FROM cadastro.fone_pessoa t1
          WHERE ((t1.tipo = (1)::numeric) AND (t.idpes = t1.idpes))) AS fone_1,
    ( SELECT t1.ddd
           FROM cadastro.fone_pessoa t1
          WHERE ((t1.tipo = (2)::numeric) AND (t.idpes = t1.idpes))) AS ddd_2,
    ( SELECT t1.fone
           FROM cadastro.fone_pessoa t1
          WHERE ((t1.tipo = (2)::numeric) AND (t.idpes = t1.idpes))) AS fone_2,
    ( SELECT t1.ddd
           FROM cadastro.fone_pessoa t1
          WHERE ((t1.tipo = (3)::numeric) AND (t.idpes = t1.idpes))) AS ddd_mov,
    ( SELECT t1.fone
           FROM cadastro.fone_pessoa t1
          WHERE ((t1.tipo = (3)::numeric) AND (t.idpes = t1.idpes))) AS fone_mov,
    ( SELECT t1.ddd
           FROM cadastro.fone_pessoa t1
          WHERE ((t1.tipo = (4)::numeric) AND (t.idpes = t1.idpes))) AS ddd_fax,
    ( SELECT t1.fone
           FROM cadastro.fone_pessoa t1
          WHERE ((t1.tipo = (4)::numeric) AND (t.idpes = t1.idpes))) AS fone_fax
   FROM cadastro.fone_pessoa t
  ORDER BY idpes, ( SELECT t1.ddd
           FROM cadastro.fone_pessoa t1
          WHERE ((t1.tipo = (1)::numeric) AND (t.idpes = t1.idpes))), ( SELECT t1.fone
           FROM cadastro.fone_pessoa t1
          WHERE ((t1.tipo = (1)::numeric) AND (t.idpes = t1.idpes))), ( SELECT t1.ddd
           FROM cadastro.fone_pessoa t1
          WHERE ((t1.tipo = (2)::numeric) AND (t.idpes = t1.idpes))), ( SELECT t1.fone
           FROM cadastro.fone_pessoa t1
          WHERE ((t1.tipo = (2)::numeric) AND (t.idpes = t1.idpes))), ( SELECT t1.ddd
           FROM cadastro.fone_pessoa t1
          WHERE ((t1.tipo = (3)::numeric) AND (t.idpes = t1.idpes))), ( SELECT t1.fone
           FROM cadastro.fone_pessoa t1
          WHERE ((t1.tipo = (3)::numeric) AND (t.idpes = t1.idpes))), ( SELECT t1.ddd
           FROM cadastro.fone_pessoa t1
          WHERE ((t1.tipo = (4)::numeric) AND (t.idpes = t1.idpes))), ( SELECT t1.fone
           FROM cadastro.fone_pessoa t1
          WHERE ((t1.tipo = (4)::numeric) AND (t.idpes = t1.idpes)));


--
-- Name: v_pessoa_fj; Type: VIEW; Schema: cadastro; Owner: -
--

CREATE VIEW cadastro.v_pessoa_fj AS
 SELECT idpes,
    nome,
    ( SELECT fisica.ref_cod_sistema
           FROM cadastro.fisica
          WHERE (fisica.idpes = p.idpes)) AS ref_cod_sistema,
    ( SELECT juridica.fantasia
           FROM cadastro.juridica
          WHERE (juridica.idpes = p.idpes)) AS fantasia,
    tipo,
    COALESCE(( SELECT fisica.cpf
           FROM cadastro.fisica
          WHERE (fisica.idpes = p.idpes)), ( SELECT juridica.cnpj
           FROM cadastro.juridica
          WHERE (juridica.idpes = p.idpes))) AS id_federal
   FROM cadastro.pessoa p;


--
-- Name: v_pessoafj_count; Type: VIEW; Schema: cadastro; Owner: -
--

CREATE VIEW cadastro.v_pessoafj_count AS
 SELECT fisica.ref_cod_sistema,
    fisica.cpf AS id_federal
   FROM cadastro.fisica
UNION ALL
 SELECT NULL::integer AS ref_cod_sistema,
    juridica.cnpj AS id_federal
   FROM cadastro.juridica;


--
-- Name: area_conhecimento; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.area_conhecimento (
    id integer NOT NULL,
    instituicao_id integer NOT NULL,
    nome character varying(200) NOT NULL,
    secao character varying(50),
    ordenamento_ac integer DEFAULT 99999,
    updated_at timestamp without time zone DEFAULT now(),
    agrupar_descritores boolean DEFAULT false NOT NULL
);


--
-- Name: area_conhecimento_excluidos; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.area_conhecimento_excluidos (
    id integer NOT NULL,
    instituicao_id integer NOT NULL,
    nome character varying(191) NOT NULL,
    secao character varying(191),
    ordenamento_ac integer,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    deleted_at timestamp(0) without time zone,
    agrupar_descritores boolean DEFAULT false NOT NULL
);


--
-- Name: area_conhecimento_id_seq; Type: SEQUENCE; Schema: modules; Owner: -
--

CREATE SEQUENCE modules.area_conhecimento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: area_conhecimento_id_seq; Type: SEQUENCE OWNED BY; Schema: modules; Owner: -
--

ALTER SEQUENCE modules.area_conhecimento_id_seq OWNED BY modules.area_conhecimento.id;


--
-- Name: auditoria; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.auditoria (
    usuario character varying(300),
    operacao smallint,
    rotina character varying(300),
    valor_antigo text,
    valor_novo text,
    data_hora timestamp without time zone
);


--
-- Name: calendario_turma; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.calendario_turma (
    calendario_ano_letivo_id integer NOT NULL,
    ano integer NOT NULL,
    mes integer NOT NULL,
    dia integer NOT NULL,
    turma_id integer NOT NULL
);


--
-- Name: componente_curricular; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.componente_curricular (
    id integer NOT NULL,
    instituicao_id integer NOT NULL,
    area_conhecimento_id integer NOT NULL,
    nome character varying(500) NOT NULL,
    abreviatura character varying(25) NOT NULL,
    tipo_base smallint NOT NULL,
    codigo_educacenso smallint,
    ordenamento integer DEFAULT 99999,
    updated_at timestamp without time zone DEFAULT now(),
    desconsidera_para_progressao boolean DEFAULT false NOT NULL
);


--
-- Name: componente_curricular_ano_escolar; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.componente_curricular_ano_escolar (
    componente_curricular_id integer NOT NULL,
    ano_escolar_id integer NOT NULL,
    carga_horaria numeric(7,3),
    tipo_nota integer,
    anos_letivos smallint[] DEFAULT '{}'::smallint[] NOT NULL,
    updated_at timestamp without time zone DEFAULT now(),
    hora_falta numeric(7,4)
);


--
-- Name: componente_curricular_ano_escolar_excluidos; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.componente_curricular_ano_escolar_excluidos (
    id integer NOT NULL,
    componente_curricular_id integer NOT NULL,
    ano_escolar_id integer NOT NULL,
    carga_horaria numeric(7,3),
    tipo_nota integer,
    anos_letivos smallint[] DEFAULT '{}'::smallint[] NOT NULL,
    updated_at timestamp(0) without time zone,
    deleted_at timestamp(0) without time zone
);


--
-- Name: componente_curricular_ano_escolar_excluidos_id_seq; Type: SEQUENCE; Schema: modules; Owner: -
--

CREATE SEQUENCE modules.componente_curricular_ano_escolar_excluidos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: componente_curricular_ano_escolar_excluidos_id_seq; Type: SEQUENCE OWNED BY; Schema: modules; Owner: -
--

ALTER SEQUENCE modules.componente_curricular_ano_escolar_excluidos_id_seq OWNED BY modules.componente_curricular_ano_escolar_excluidos.id;


--
-- Name: componente_curricular_id_seq; Type: SEQUENCE; Schema: modules; Owner: -
--

CREATE SEQUENCE modules.componente_curricular_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: componente_curricular_id_seq; Type: SEQUENCE OWNED BY; Schema: modules; Owner: -
--

ALTER SEQUENCE modules.componente_curricular_id_seq OWNED BY modules.componente_curricular.id;


--
-- Name: componente_curricular_turma; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.componente_curricular_turma (
    componente_curricular_id integer NOT NULL,
    ano_escolar_id integer NOT NULL,
    escola_id integer NOT NULL,
    turma_id integer NOT NULL,
    carga_horaria numeric(7,3),
    docente_vinculado smallint,
    etapas_especificas smallint,
    etapas_utilizadas character varying,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: componente_curricular_turma_excluidos; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.componente_curricular_turma_excluidos (
    componente_curricular_id integer NOT NULL,
    ano_escolar_id integer NOT NULL,
    escola_id integer NOT NULL,
    turma_id integer NOT NULL,
    carga_horaria double precision,
    docente_vinculado integer,
    etapas_especificas integer,
    etapas_utilizadas character varying(191),
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    deleted_at timestamp(0) without time zone
);


--
-- Name: config_movimento_geral; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.config_movimento_geral (
    id integer NOT NULL,
    ref_cod_serie integer NOT NULL,
    coluna integer NOT NULL
);


--
-- Name: config_movimento_geral_id_seq; Type: SEQUENCE; Schema: modules; Owner: -
--

CREATE SEQUENCE modules.config_movimento_geral_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: config_movimento_geral_id_seq; Type: SEQUENCE OWNED BY; Schema: modules; Owner: -
--

ALTER SEQUENCE modules.config_movimento_geral_id_seq OWNED BY modules.config_movimento_geral.id;


--
-- Name: educacenso_cod_aluno; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.educacenso_cod_aluno (
    cod_aluno integer NOT NULL,
    cod_aluno_inep bigint NOT NULL,
    nome_inep character varying(255),
    fonte character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone,
    id integer NOT NULL
);


--
-- Name: educacenso_cod_aluno_id_seq; Type: SEQUENCE; Schema: modules; Owner: -
--

CREATE SEQUENCE modules.educacenso_cod_aluno_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: educacenso_cod_aluno_id_seq; Type: SEQUENCE OWNED BY; Schema: modules; Owner: -
--

ALTER SEQUENCE modules.educacenso_cod_aluno_id_seq OWNED BY modules.educacenso_cod_aluno.id;


--
-- Name: educacenso_cod_docente; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.educacenso_cod_docente (
    cod_servidor integer NOT NULL,
    cod_docente_inep bigint NOT NULL,
    nome_inep character varying(255),
    fonte character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone,
    id integer NOT NULL
);


--
-- Name: educacenso_cod_docente_id_seq; Type: SEQUENCE; Schema: modules; Owner: -
--

CREATE SEQUENCE modules.educacenso_cod_docente_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: educacenso_cod_docente_id_seq; Type: SEQUENCE OWNED BY; Schema: modules; Owner: -
--

ALTER SEQUENCE modules.educacenso_cod_docente_id_seq OWNED BY modules.educacenso_cod_docente.id;


--
-- Name: educacenso_cod_escola; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.educacenso_cod_escola (
    cod_escola integer NOT NULL,
    cod_escola_inep bigint NOT NULL,
    nome_inep character varying(255),
    fonte character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone,
    id integer NOT NULL
);


--
-- Name: educacenso_cod_escola_id_seq; Type: SEQUENCE; Schema: modules; Owner: -
--

CREATE SEQUENCE modules.educacenso_cod_escola_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: educacenso_cod_escola_id_seq; Type: SEQUENCE OWNED BY; Schema: modules; Owner: -
--

ALTER SEQUENCE modules.educacenso_cod_escola_id_seq OWNED BY modules.educacenso_cod_escola.id;


--
-- Name: educacenso_cod_turma; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.educacenso_cod_turma (
    cod_turma integer NOT NULL,
    cod_turma_inep bigint NOT NULL,
    nome_inep character varying(255),
    fonte character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone,
    id integer NOT NULL,
    turma_turno_id smallint
);


--
-- Name: educacenso_cod_turma_id_seq; Type: SEQUENCE; Schema: modules; Owner: -
--

CREATE SEQUENCE modules.educacenso_cod_turma_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: educacenso_cod_turma_id_seq; Type: SEQUENCE OWNED BY; Schema: modules; Owner: -
--

ALTER SEQUENCE modules.educacenso_cod_turma_id_seq OWNED BY modules.educacenso_cod_turma.id;


--
-- Name: educacenso_curso_superior; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.educacenso_curso_superior (
    id integer NOT NULL,
    curso_id character varying(100) NOT NULL,
    nome character varying(255) NOT NULL,
    classe_id integer NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone,
    grau_academico smallint
);


--
-- Name: educacenso_curso_superior_id_seq; Type: SEQUENCE; Schema: modules; Owner: -
--

CREATE SEQUENCE modules.educacenso_curso_superior_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: educacenso_curso_superior_id_seq; Type: SEQUENCE OWNED BY; Schema: modules; Owner: -
--

ALTER SEQUENCE modules.educacenso_curso_superior_id_seq OWNED BY modules.educacenso_curso_superior.id;


--
-- Name: educacenso_ies; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.educacenso_ies (
    id integer NOT NULL,
    ies_id integer NOT NULL,
    nome character varying(255) NOT NULL,
    dependencia_administrativa_id integer NOT NULL,
    tipo_instituicao_id integer NOT NULL,
    uf character(2),
    user_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone
);


--
-- Name: educacenso_ies_id_seq; Type: SEQUENCE; Schema: modules; Owner: -
--

CREATE SEQUENCE modules.educacenso_ies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: educacenso_ies_id_seq; Type: SEQUENCE OWNED BY; Schema: modules; Owner: -
--

ALTER SEQUENCE modules.educacenso_ies_id_seq OWNED BY modules.educacenso_ies.id;


--
-- Name: educacenso_matricula; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.educacenso_matricula (
    id bigint NOT NULL,
    matricula_turma_id bigint NOT NULL,
    matricula_inep bigint,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: educacenso_matricula_id_seq; Type: SEQUENCE; Schema: modules; Owner: -
--

CREATE SEQUENCE modules.educacenso_matricula_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: educacenso_matricula_id_seq; Type: SEQUENCE OWNED BY; Schema: modules; Owner: -
--

ALTER SEQUENCE modules.educacenso_matricula_id_seq OWNED BY modules.educacenso_matricula.id;


--
-- Name: educacenso_orgao_regional; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.educacenso_orgao_regional (
    sigla_uf character varying(2) NOT NULL,
    codigo character varying(5) NOT NULL
);


--
-- Name: etapas_curso_educacenso; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.etapas_curso_educacenso (
    etapa_id integer NOT NULL,
    curso_id integer NOT NULL
);


--
-- Name: etapas_educacenso; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.etapas_educacenso (
    id integer NOT NULL,
    nome character varying(255)
);


--
-- Name: falta_aluno; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.falta_aluno (
    id integer NOT NULL,
    matricula_id integer NOT NULL,
    tipo_falta smallint NOT NULL
);


--
-- Name: falta_aluno_id_seq; Type: SEQUENCE; Schema: modules; Owner: -
--

CREATE SEQUENCE modules.falta_aluno_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: falta_aluno_id_seq; Type: SEQUENCE OWNED BY; Schema: modules; Owner: -
--

ALTER SEQUENCE modules.falta_aluno_id_seq OWNED BY modules.falta_aluno.id;


--
-- Name: falta_componente_curricular; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.falta_componente_curricular (
    id integer NOT NULL,
    falta_aluno_id integer NOT NULL,
    componente_curricular_id integer NOT NULL,
    quantidade integer DEFAULT 0,
    etapa character varying(2) NOT NULL
);


--
-- Name: falta_componente_curricular_id_seq; Type: SEQUENCE; Schema: modules; Owner: -
--

CREATE SEQUENCE modules.falta_componente_curricular_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: falta_componente_curricular_id_seq; Type: SEQUENCE OWNED BY; Schema: modules; Owner: -
--

ALTER SEQUENCE modules.falta_componente_curricular_id_seq OWNED BY modules.falta_componente_curricular.id;


--
-- Name: falta_geral; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.falta_geral (
    id integer NOT NULL,
    falta_aluno_id integer NOT NULL,
    quantidade integer DEFAULT 0,
    etapa character varying(2) NOT NULL
);


--
-- Name: falta_geral_id_seq; Type: SEQUENCE; Schema: modules; Owner: -
--

CREATE SEQUENCE modules.falta_geral_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: falta_geral_id_seq; Type: SEQUENCE OWNED BY; Schema: modules; Owner: -
--

ALTER SEQUENCE modules.falta_geral_id_seq OWNED BY modules.falta_geral.id;


--
-- Name: ficha_medica_aluno; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.ficha_medica_aluno (
    ref_cod_aluno integer NOT NULL,
    grupo_sanguineo character varying(2),
    fator_rh character varying(1),
    alergia_medicamento character(1),
    desc_alergia_medicamento character varying(100),
    alergia_alimento character(1),
    desc_alergia_alimento character varying(100),
    doenca_congenita character(1),
    desc_doenca_congenita character varying(100),
    fumante character(1),
    doenca_caxumba character(1),
    doenca_sarampo character(1),
    doenca_rubeola character(1),
    doenca_catapora character(1),
    doenca_escarlatina character(1),
    doenca_coqueluche character(1),
    doenca_outras character varying(100),
    epiletico character(1),
    epiletico_tratamento character(1),
    hemofilico character(1),
    hipertenso character(1),
    asmatico character(1),
    diabetico character(1),
    insulina character(1),
    tratamento_medico character(1),
    desc_tratamento_medico character varying(100),
    medicacao_especifica character(1),
    desc_medicacao_especifica character varying(100),
    acomp_medico_psicologico character(1),
    desc_acomp_medico_psicologico character varying(100),
    restricao_atividade_fisica character(1),
    desc_restricao_atividade_fisica character varying(100),
    fratura_trauma character(1),
    desc_fratura_trauma character varying(100),
    plano_saude character(1),
    desc_plano_saude character varying(50),
    responsavel character varying(50),
    responsavel_parentesco character varying(20),
    responsavel_parentesco_telefone character varying(20),
    responsavel_parentesco_celular character varying(20),
    observacao character varying(255),
    aceita_hospital_proximo character(1),
    desc_aceita_hospital_proximo character varying(191)
);


--
-- Name: formula_media; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.formula_media (
    id integer NOT NULL,
    instituicao_id integer NOT NULL,
    nome character varying(50) NOT NULL,
    formula_media character varying(200) NOT NULL,
    tipo_formula smallint DEFAULT 1,
    substitui_menor_nota_rc smallint DEFAULT 0 NOT NULL
);


--
-- Name: formula_media_id_seq; Type: SEQUENCE; Schema: modules; Owner: -
--

CREATE SEQUENCE modules.formula_media_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: formula_media_id_seq; Type: SEQUENCE OWNED BY; Schema: modules; Owner: -
--

ALTER SEQUENCE modules.formula_media_id_seq OWNED BY modules.formula_media.id;


--
-- Name: lingua_indigena_educacenso; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.lingua_indigena_educacenso (
    id integer NOT NULL,
    lingua character varying(255)
);


--
-- Name: media_geral; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.media_geral (
    nota_aluno_id integer NOT NULL,
    media numeric(8,4) DEFAULT 0,
    media_arredondada character varying(10) DEFAULT 0,
    etapa character varying(2) NOT NULL
);


--
-- Name: moradia_aluno; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.moradia_aluno (
    ref_cod_aluno integer NOT NULL,
    moradia character(1),
    material character(1) DEFAULT 'A'::bpchar,
    casa_outra character varying(20),
    moradia_situacao integer,
    quartos integer,
    sala integer,
    copa integer,
    banheiro integer,
    garagem integer,
    empregada_domestica character(1),
    automovel character(1),
    motocicleta character(1),
    geladeira character(1),
    fogao character(1),
    maquina_lavar character(1),
    microondas character(1),
    video_dvd character(1),
    televisao character(1),
    telefone character(1),
    quant_pessoas integer,
    renda double precision,
    agua_encanada character(1),
    poco character(1),
    energia character(1),
    esgoto character(1),
    fossa character(1),
    lixo character(1),
    recursos_tecnologicos json
);


--
-- Name: nota_aluno; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.nota_aluno (
    id integer NOT NULL,
    matricula_id integer NOT NULL
);


--
-- Name: nota_aluno_id_seq; Type: SEQUENCE; Schema: modules; Owner: -
--

CREATE SEQUENCE modules.nota_aluno_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: nota_aluno_id_seq; Type: SEQUENCE OWNED BY; Schema: modules; Owner: -
--

ALTER SEQUENCE modules.nota_aluno_id_seq OWNED BY modules.nota_aluno.id;


--
-- Name: nota_componente_curricular; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.nota_componente_curricular (
    id integer NOT NULL,
    nota_aluno_id integer NOT NULL,
    componente_curricular_id integer NOT NULL,
    nota numeric(8,4) DEFAULT 0,
    nota_arredondada character varying(10) DEFAULT 0,
    etapa character varying(2) NOT NULL,
    nota_recuperacao character varying(10),
    nota_original character varying(10),
    nota_recuperacao_especifica character varying(10)
);


--
-- Name: nota_componente_curricular_id_seq; Type: SEQUENCE; Schema: modules; Owner: -
--

CREATE SEQUENCE modules.nota_componente_curricular_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: nota_componente_curricular_id_seq; Type: SEQUENCE OWNED BY; Schema: modules; Owner: -
--

ALTER SEQUENCE modules.nota_componente_curricular_id_seq OWNED BY modules.nota_componente_curricular.id;


--
-- Name: nota_componente_curricular_media; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.nota_componente_curricular_media (
    nota_aluno_id integer NOT NULL,
    componente_curricular_id integer NOT NULL,
    media numeric(8,4) DEFAULT 0,
    media_arredondada character varying(10) DEFAULT 0,
    etapa character varying(2) NOT NULL,
    situacao integer,
    bloqueada boolean DEFAULT false NOT NULL
);


--
-- Name: nota_exame; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.nota_exame (
    ref_cod_matricula integer NOT NULL,
    ref_cod_componente_curricular integer NOT NULL,
    nota_exame numeric(6,3)
);


--
-- Name: nota_geral_id_seq; Type: SEQUENCE; Schema: modules; Owner: -
--

CREATE SEQUENCE modules.nota_geral_id_seq
    START WITH 958638
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: nota_geral; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.nota_geral (
    id integer DEFAULT nextval('modules.nota_geral_id_seq'::regclass) NOT NULL,
    nota_aluno_id integer NOT NULL,
    nota numeric(8,4) DEFAULT 0,
    nota_arredondada character varying(10) DEFAULT 0,
    etapa character varying(2) NOT NULL
);


--
-- Name: parecer_aluno; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.parecer_aluno (
    id integer NOT NULL,
    matricula_id integer NOT NULL,
    parecer_descritivo smallint NOT NULL
);


--
-- Name: parecer_aluno_id_seq; Type: SEQUENCE; Schema: modules; Owner: -
--

CREATE SEQUENCE modules.parecer_aluno_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: parecer_aluno_id_seq; Type: SEQUENCE OWNED BY; Schema: modules; Owner: -
--

ALTER SEQUENCE modules.parecer_aluno_id_seq OWNED BY modules.parecer_aluno.id;


--
-- Name: parecer_componente_curricular; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.parecer_componente_curricular (
    id integer NOT NULL,
    parecer_aluno_id integer NOT NULL,
    componente_curricular_id integer NOT NULL,
    parecer text,
    etapa character varying(2) NOT NULL
);


--
-- Name: parecer_componente_curricular_id_seq; Type: SEQUENCE; Schema: modules; Owner: -
--

CREATE SEQUENCE modules.parecer_componente_curricular_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: parecer_componente_curricular_id_seq; Type: SEQUENCE OWNED BY; Schema: modules; Owner: -
--

ALTER SEQUENCE modules.parecer_componente_curricular_id_seq OWNED BY modules.parecer_componente_curricular.id;


--
-- Name: parecer_geral; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.parecer_geral (
    id integer NOT NULL,
    parecer_aluno_id integer NOT NULL,
    parecer text,
    etapa character varying(2) NOT NULL
);


--
-- Name: parecer_geral_id_seq; Type: SEQUENCE; Schema: modules; Owner: -
--

CREATE SEQUENCE modules.parecer_geral_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: parecer_geral_id_seq; Type: SEQUENCE OWNED BY; Schema: modules; Owner: -
--

ALTER SEQUENCE modules.parecer_geral_id_seq OWNED BY modules.parecer_geral.id;


--
-- Name: povo_indigena_educacenso; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.povo_indigena_educacenso (
    id bigint NOT NULL,
    name character varying(191),
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: povo_indigena_educacenso_id_seq; Type: SEQUENCE; Schema: modules; Owner: -
--

CREATE SEQUENCE modules.povo_indigena_educacenso_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: povo_indigena_educacenso_id_seq; Type: SEQUENCE OWNED BY; Schema: modules; Owner: -
--

ALTER SEQUENCE modules.povo_indigena_educacenso_id_seq OWNED BY modules.povo_indigena_educacenso.id;


--
-- Name: professor_turma_id_seq; Type: SEQUENCE; Schema: modules; Owner: -
--

CREATE SEQUENCE modules.professor_turma_id_seq
    START WITH 1
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: professor_turma; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.professor_turma (
    id integer DEFAULT nextval('modules.professor_turma_id_seq'::regclass) NOT NULL,
    ano smallint NOT NULL,
    instituicao_id integer NOT NULL,
    turma_id integer NOT NULL,
    servidor_id integer NOT NULL,
    funcao_exercida smallint NOT NULL,
    tipo_vinculo smallint,
    permite_lancar_faltas_componente integer DEFAULT 0,
    updated_at timestamp without time zone,
    turno_id integer,
    unidades_curriculares smallint[],
    outras_unidades_curriculares_obrigatorias smallint DEFAULT '0'::smallint,
    data_inicial date,
    data_fim date,
    area_itinerario smallint[],
    leciona_itinerario_tecnico_profissional smallint
);


--
-- Name: professor_turma_disciplina; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.professor_turma_disciplina (
    professor_turma_id integer NOT NULL,
    componente_curricular_id integer NOT NULL
);


--
-- Name: professor_turma_excluidos; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.professor_turma_excluidos (
    id integer NOT NULL,
    ano integer NOT NULL,
    instituicao_id integer NOT NULL,
    turma_id integer NOT NULL,
    servidor_id integer NOT NULL,
    funcao_exercida integer NOT NULL,
    tipo_vinculo integer,
    permite_lancar_faltas_componente integer,
    turno_id integer,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    deleted_at timestamp(0) without time zone
);


--
-- Name: regra_avaliacao; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.regra_avaliacao (
    id integer NOT NULL,
    instituicao_id integer NOT NULL,
    formula_media_id integer,
    formula_recuperacao_id integer,
    tabela_arredondamento_id integer,
    nome character varying(50) NOT NULL,
    tipo_nota smallint NOT NULL,
    tipo_progressao smallint NOT NULL,
    media numeric(6,3),
    porcentagem_presenca numeric(6,3) DEFAULT 0.000,
    parecer_descritivo smallint DEFAULT 0,
    tipo_presenca smallint NOT NULL,
    media_recuperacao numeric(6,3),
    tipo_recuperacao_paralela smallint DEFAULT 0,
    media_recuperacao_paralela numeric(5,3),
    nota_maxima_geral integer DEFAULT 10 NOT NULL,
    nota_maxima_exame_final integer DEFAULT 10 NOT NULL,
    qtd_casas_decimais integer DEFAULT 2 NOT NULL,
    nota_geral_por_etapa smallint DEFAULT 0,
    qtd_disciplinas_dependencia smallint DEFAULT 0 NOT NULL,
    aprova_media_disciplina smallint DEFAULT 0,
    reprovacao_automatica smallint DEFAULT 0,
    definir_componente_etapa smallint,
    qtd_matriculas_dependencia smallint DEFAULT 0 NOT NULL,
    nota_minima_geral integer DEFAULT 0,
    tabela_arredondamento_id_conceitual integer,
    regra_diferenciada_id integer,
    updated_at timestamp without time zone DEFAULT now(),
    calcula_media_rec_paralela smallint DEFAULT '0'::smallint NOT NULL,
    tipo_calculo_recuperacao_paralela integer DEFAULT 1 NOT NULL,
    disciplinas_aglutinadas character varying(191),
    desconsiderar_lancamento_frequencia boolean DEFAULT false NOT NULL,
    falta_minima_geral integer DEFAULT 0 NOT NULL,
    falta_maxima_geral integer DEFAULT 100 NOT NULL,
    aprovar_pela_frequencia_apos_exame boolean DEFAULT false NOT NULL,
    reprovar_automaticamente_apos_dependencias smallint DEFAULT '0'::smallint NOT NULL,
    pontos character varying(191)
);


--
-- Name: regra_avaliacao_id_seq; Type: SEQUENCE; Schema: modules; Owner: -
--

CREATE SEQUENCE modules.regra_avaliacao_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: regra_avaliacao_id_seq; Type: SEQUENCE OWNED BY; Schema: modules; Owner: -
--

ALTER SEQUENCE modules.regra_avaliacao_id_seq OWNED BY modules.regra_avaliacao.id;


--
-- Name: regra_avaliacao_recuperacao_id_seq; Type: SEQUENCE; Schema: modules; Owner: -
--

CREATE SEQUENCE modules.regra_avaliacao_recuperacao_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: regra_avaliacao_recuperacao; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.regra_avaliacao_recuperacao (
    id integer DEFAULT nextval('modules.regra_avaliacao_recuperacao_id_seq'::regclass) NOT NULL,
    regra_avaliacao_id integer NOT NULL,
    descricao character varying(25) NOT NULL,
    etapas_recuperadas character varying(25) NOT NULL,
    substitui_menor_nota boolean,
    media numeric(8,4) NOT NULL,
    nota_maxima numeric(8,4) NOT NULL,
    updated_at timestamp without time zone DEFAULT now()
);


--
-- Name: regra_avaliacao_recuperacao_excluidos; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.regra_avaliacao_recuperacao_excluidos (
    id integer NOT NULL,
    regra_avaliacao_id integer NOT NULL,
    descricao character varying(191) NOT NULL,
    etapas_recuperadas character varying(191) NOT NULL,
    substitui_menor_nota boolean,
    media double precision NOT NULL,
    nota_maxima double precision NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    deleted_at timestamp(0) without time zone
);


--
-- Name: regra_avaliacao_serie_ano; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.regra_avaliacao_serie_ano (
    serie_id integer NOT NULL,
    regra_avaliacao_id integer NOT NULL,
    regra_avaliacao_diferenciada_id integer,
    ano_letivo smallint NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: regra_avaliacao_serie_ano_excluidos; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.regra_avaliacao_serie_ano_excluidos (
    id integer NOT NULL,
    serie_id integer NOT NULL,
    regra_avaliacao_id integer NOT NULL,
    regra_avaliacao_diferenciada_id integer,
    ano_letivo integer NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    deleted_at timestamp(0) without time zone
);


--
-- Name: regra_avaliacao_serie_ano_excluidos_id_seq; Type: SEQUENCE; Schema: modules; Owner: -
--

CREATE SEQUENCE modules.regra_avaliacao_serie_ano_excluidos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: regra_avaliacao_serie_ano_excluidos_id_seq; Type: SEQUENCE OWNED BY; Schema: modules; Owner: -
--

ALTER SEQUENCE modules.regra_avaliacao_serie_ano_excluidos_id_seq OWNED BY modules.regra_avaliacao_serie_ano_excluidos.id;


--
-- Name: tabela_arredondamento; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.tabela_arredondamento (
    id integer NOT NULL,
    instituicao_id integer NOT NULL,
    nome character varying(50) NOT NULL,
    tipo_nota smallint DEFAULT 1 NOT NULL,
    updated_at timestamp without time zone DEFAULT now(),
    arredondar_nota smallint DEFAULT '0'::smallint NOT NULL
);


--
-- Name: tabela_arredondamento_id_seq; Type: SEQUENCE; Schema: modules; Owner: -
--

CREATE SEQUENCE modules.tabela_arredondamento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tabela_arredondamento_id_seq; Type: SEQUENCE OWNED BY; Schema: modules; Owner: -
--

ALTER SEQUENCE modules.tabela_arredondamento_id_seq OWNED BY modules.tabela_arredondamento.id;


--
-- Name: tabela_arredondamento_valor; Type: TABLE; Schema: modules; Owner: -
--

CREATE TABLE modules.tabela_arredondamento_valor (
    id integer NOT NULL,
    tabela_arredondamento_id integer NOT NULL,
    nome character varying(5) NOT NULL,
    descricao character varying(50),
    valor_minimo numeric(5,3),
    valor_maximo numeric(5,3),
    casa_decimal_exata smallint,
    acao smallint,
    observacao character varying(191)
);


--
-- Name: tabela_arredondamento_valor_id_seq; Type: SEQUENCE; Schema: modules; Owner: -
--

CREATE SEQUENCE modules.tabela_arredondamento_valor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tabela_arredondamento_valor_id_seq; Type: SEQUENCE OWNED BY; Schema: modules; Owner: -
--

ALTER SEQUENCE modules.tabela_arredondamento_valor_id_seq OWNED BY modules.tabela_arredondamento_valor.id;


--
-- Name: abandono_tipo_cod_abandono_tipo_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.abandono_tipo_cod_abandono_tipo_seq
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: abandono_tipo; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.abandono_tipo (
    cod_abandono_tipo integer DEFAULT nextval('pmieducar.abandono_tipo_cod_abandono_tipo_seq'::regclass) NOT NULL,
    ref_cod_instituicao integer NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer,
    nome character varying(255) NOT NULL,
    data_cadastro timestamp without time zone,
    data_exclusao timestamp without time zone,
    ativo integer
);


--
-- Name: aluno_cod_aluno_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.aluno_cod_aluno_seq
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: aluno; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.aluno (
    cod_aluno integer DEFAULT nextval('pmieducar.aluno_cod_aluno_seq'::regclass) NOT NULL,
    ref_cod_religiao integer,
    ref_usuario_exc integer,
    ref_usuario_cad integer,
    ref_idpes integer,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    caminho_foto character varying(255),
    analfabeto smallint DEFAULT (0)::smallint,
    nm_pai character varying(255),
    nm_mae character varying(255),
    tipo_responsavel character(1),
    aluno_estado_id character varying(25),
    justificativa_falta_documentacao smallint,
    url_laudo_medico json,
    codigo_sistema character varying(30),
    veiculo_transporte_escolar integer[],
    autorizado_um character varying(150),
    parentesco_um character varying(150),
    autorizado_dois character varying(150),
    parentesco_dois character varying(150),
    autorizado_tres character varying(150),
    parentesco_tres character varying(150),
    autorizado_quatro character varying(150),
    parentesco_quatro character varying(150),
    autorizado_cinco character varying(150),
    parentesco_cinco character varying(150),
    url_documento json,
    recebe_escolarizacao_em_outro_espaco smallint DEFAULT 1 NOT NULL,
    recursos_prova_inep integer[],
    updated_at timestamp without time zone DEFAULT now(),
    emancipado boolean DEFAULT false NOT NULL,
    tipo_transporte integer DEFAULT 0 NOT NULL,
    rota_transporte text,
    utiliza_transporte_rural boolean DEFAULT false NOT NULL
);


--
-- Name: aluno_aluno_beneficio; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.aluno_aluno_beneficio (
    aluno_id integer NOT NULL,
    aluno_beneficio_id integer NOT NULL,
    id bigint NOT NULL
);


--
-- Name: aluno_aluno_beneficio_id_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.aluno_aluno_beneficio_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: aluno_aluno_beneficio_id_seq; Type: SEQUENCE OWNED BY; Schema: pmieducar; Owner: -
--

ALTER SEQUENCE pmieducar.aluno_aluno_beneficio_id_seq OWNED BY pmieducar.aluno_aluno_beneficio.id;


--
-- Name: aluno_beneficio_cod_aluno_beneficio_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.aluno_beneficio_cod_aluno_beneficio_seq
    START WITH 1
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: aluno_beneficio; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.aluno_beneficio (
    cod_aluno_beneficio integer DEFAULT nextval('pmieducar.aluno_beneficio_cod_aluno_beneficio_seq'::regclass) NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    nm_beneficio character varying(255) NOT NULL,
    desc_beneficio text,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL
);


--
-- Name: aluno_excluidos; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.aluno_excluidos (
    cod_aluno integer NOT NULL,
    ref_idpes integer,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    deleted_at timestamp(0) without time zone
);


--
-- Name: aluno_historico_altura_peso; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.aluno_historico_altura_peso (
    ref_cod_aluno integer NOT NULL,
    data_historico date NOT NULL,
    altura numeric(12,2) NOT NULL,
    peso numeric(12,2) NOT NULL,
    id integer NOT NULL
);


--
-- Name: aluno_historico_altura_peso_id_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.aluno_historico_altura_peso_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: aluno_historico_altura_peso_id_seq; Type: SEQUENCE OWNED BY; Schema: pmieducar; Owner: -
--

ALTER SEQUENCE pmieducar.aluno_historico_altura_peso_id_seq OWNED BY pmieducar.aluno_historico_altura_peso.id;


--
-- Name: ano_letivo_modulo; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.ano_letivo_modulo (
    ref_ano smallint NOT NULL,
    ref_ref_cod_escola integer NOT NULL,
    sequencial smallint NOT NULL,
    ref_cod_modulo smallint NOT NULL,
    data_inicio date NOT NULL,
    data_fim date NOT NULL,
    dias_letivos smallint,
    id integer NOT NULL,
    escola_ano_letivo_id integer NOT NULL
);


--
-- Name: ano_letivo_modulo_id_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.ano_letivo_modulo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ano_letivo_modulo_id_seq; Type: SEQUENCE OWNED BY; Schema: pmieducar; Owner: -
--

ALTER SEQUENCE pmieducar.ano_letivo_modulo_id_seq OWNED BY pmieducar.ano_letivo_modulo.id;


--
-- Name: backup; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.backup (
    id integer NOT NULL,
    caminho character varying(255) NOT NULL,
    data_backup timestamp without time zone
);


--
-- Name: backup_id_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.backup_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: backup_id_seq; Type: SEQUENCE OWNED BY; Schema: pmieducar; Owner: -
--

ALTER SEQUENCE pmieducar.backup_id_seq OWNED BY pmieducar.backup.id;


--
-- Name: bloqueio_ano_letivo; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.bloqueio_ano_letivo (
    ref_cod_instituicao integer NOT NULL,
    ref_ano integer NOT NULL,
    data_inicio date NOT NULL,
    data_fim date NOT NULL
);


--
-- Name: bloqueio_lancamento_faltas_notas_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bloqueio_lancamento_faltas_notas_seq
    START WITH 1
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: bloqueio_lancamento_faltas_notas; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.bloqueio_lancamento_faltas_notas (
    cod_bloqueio integer DEFAULT nextval('public.bloqueio_lancamento_faltas_notas_seq'::regclass) NOT NULL,
    ano integer NOT NULL,
    ref_cod_escola integer NOT NULL,
    etapa integer NOT NULL,
    data_inicio date NOT NULL,
    data_fim date NOT NULL
);


--
-- Name: busca_ativa; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.busca_ativa (
    id bigint NOT NULL,
    ref_cod_matricula integer NOT NULL,
    data_inicio date NOT NULL,
    data_fim date,
    resultado_busca_ativa smallint DEFAULT '2'::smallint NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    deleted_at timestamp(0) without time zone,
    aluno_incluso_programa_evasao boolean DEFAULT false NOT NULL
);


--
-- Name: busca_ativa_id_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.busca_ativa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: busca_ativa_id_seq; Type: SEQUENCE OWNED BY; Schema: pmieducar; Owner: -
--

ALTER SEQUENCE pmieducar.busca_ativa_id_seq OWNED BY pmieducar.busca_ativa.id;


--
-- Name: calendario_ano_letivo_cod_calendario_ano_letivo_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.calendario_ano_letivo_cod_calendario_ano_letivo_seq
    START WITH 1
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: calendario_ano_letivo; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.calendario_ano_letivo (
    cod_calendario_ano_letivo integer DEFAULT nextval('pmieducar.calendario_ano_letivo_cod_calendario_ano_letivo_seq'::regclass) NOT NULL,
    ref_cod_escola integer NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    ano integer NOT NULL,
    data_cadastra timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL
);


--
-- Name: calendario_anotacao_cod_calendario_anotacao_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.calendario_anotacao_cod_calendario_anotacao_seq
    START WITH 1
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: calendario_anotacao; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.calendario_anotacao (
    cod_calendario_anotacao integer DEFAULT nextval('pmieducar.calendario_anotacao_cod_calendario_anotacao_seq'::regclass) NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    nm_anotacao character varying(255) NOT NULL,
    descricao text,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint NOT NULL
);


--
-- Name: calendario_dia; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.calendario_dia (
    ref_cod_calendario_ano_letivo integer NOT NULL,
    mes integer NOT NULL,
    dia integer NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    ref_cod_calendario_dia_motivo integer,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    descricao text,
    id integer NOT NULL
);


--
-- Name: calendario_dia_anotacao; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.calendario_dia_anotacao (
    ref_dia integer NOT NULL,
    ref_mes integer NOT NULL,
    ref_ref_cod_calendario_ano_letivo integer NOT NULL,
    ref_cod_calendario_anotacao integer NOT NULL
);


--
-- Name: calendario_dia_id_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.calendario_dia_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: calendario_dia_id_seq; Type: SEQUENCE OWNED BY; Schema: pmieducar; Owner: -
--

ALTER SEQUENCE pmieducar.calendario_dia_id_seq OWNED BY pmieducar.calendario_dia.id;


--
-- Name: calendario_dia_motivo_cod_calendario_dia_motivo_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.calendario_dia_motivo_cod_calendario_dia_motivo_seq
    START WITH 1
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: calendario_dia_motivo; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.calendario_dia_motivo (
    cod_calendario_dia_motivo integer DEFAULT nextval('pmieducar.calendario_dia_motivo_cod_calendario_dia_motivo_seq'::regclass) NOT NULL,
    ref_cod_escola integer NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    sigla character varying(15) NOT NULL,
    descricao text,
    tipo character(1) NOT NULL,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    nm_motivo character varying(255) NOT NULL
);


--
-- Name: configuracoes_gerais; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.configuracoes_gerais (
    ref_cod_instituicao integer NOT NULL,
    permite_relacionamento_posvendas integer DEFAULT 1 NOT NULL,
    url_novo_educacao character varying(100),
    mostrar_codigo_inep_aluno smallint DEFAULT 1,
    justificativa_falta_documentacao_obrigatorio smallint DEFAULT 1,
    tamanho_min_rede_estadual integer,
    modelo_boletim_professor integer DEFAULT 1,
    custom_labels json,
    url_cadastro_usuario character varying(255) DEFAULT NULL::character varying,
    active_on_ieducar smallint DEFAULT 1,
    ieducar_image character varying(255) DEFAULT NULL::character varying,
    ieducar_entity_name character varying(255) DEFAULT NULL::character varying,
    ieducar_login_footer text DEFAULT '<p>Comunidade i-Educar - <a class="light" href="https://forum.ieducar.org/" target="_blank"> Obter Suporte </a></p>'::character varying,
    ieducar_external_footer text DEFAULT '<p>Conheça mais sobre o i-Educar, acesse nosso <a href="https://ieducar.org/blog/">blog</a>.</p>'::character varying,
    ieducar_internal_footer text DEFAULT '<p>Conheça mais sobre o i-Educar, acesse nosso <a href="https://ieducar.org/blog/">blog</a>.</p>'::character varying,
    facebook_url character varying(255) DEFAULT 'https://www.facebook.com/portabilis'::character varying,
    twitter_url character varying(255) DEFAULT 'https://twitter.com/portabilis'::character varying,
    linkedin_url character varying(255) DEFAULT 'https://www.linkedin.com/company/portabilis-tecnologia'::character varying,
    ieducar_suspension_message text,
    bloquear_cadastro_aluno boolean DEFAULT false NOT NULL,
    token_novo_educacao character varying(191),
    situacoes_especificas_atestados boolean DEFAULT false NOT NULL,
    emitir_ato_autorizativo boolean DEFAULT false NOT NULL,
    emitir_ato_criacao_credenciamento boolean DEFAULT false NOT NULL
);


--
-- Name: curso_cod_curso_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.curso_cod_curso_seq
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: curso; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.curso (
    cod_curso integer DEFAULT nextval('pmieducar.curso_cod_curso_seq'::regclass) NOT NULL,
    ref_usuario_cad integer NOT NULL,
    ref_cod_tipo_regime integer,
    ref_cod_nivel_ensino integer NOT NULL,
    ref_cod_tipo_ensino integer NOT NULL,
    nm_curso character varying(255) NOT NULL,
    sgl_curso character varying(15) NOT NULL,
    qtd_etapas smallint NOT NULL,
    carga_horaria double precision NOT NULL,
    ato_poder_publico character varying(255),
    objetivo_curso text,
    publico_alvo text,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    ref_usuario_exc integer,
    ref_cod_instituicao integer NOT NULL,
    padrao_ano_escolar smallint DEFAULT (0)::smallint NOT NULL,
    hora_falta double precision DEFAULT 0.00 NOT NULL,
    multi_seriado integer,
    modalidade_curso integer,
    updated_at timestamp without time zone DEFAULT now(),
    importar_curso_pre_matricula boolean DEFAULT false NOT NULL,
    descricao character varying(50),
    bloquear_novas_matriculas boolean DEFAULT false NOT NULL
);


--
-- Name: disciplina_dependencia; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.disciplina_dependencia (
    ref_cod_matricula integer NOT NULL,
    ref_cod_disciplina integer NOT NULL,
    ref_cod_escola integer NOT NULL,
    ref_cod_serie integer NOT NULL,
    observacao text,
    cod_disciplina_dependencia integer NOT NULL,
    updated_at timestamp without time zone DEFAULT now()
);


--
-- Name: disciplina_dependencia_excluidos; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.disciplina_dependencia_excluidos (
    cod_disciplina_dependencia integer NOT NULL,
    ref_cod_matricula integer NOT NULL,
    ref_cod_disciplina integer NOT NULL,
    ref_cod_escola integer NOT NULL,
    ref_cod_serie integer NOT NULL,
    observacao text,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    deleted_at timestamp(0) without time zone
);


--
-- Name: disciplina_serie; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.disciplina_serie (
    ref_cod_disciplina integer NOT NULL,
    ref_cod_serie integer NOT NULL,
    ativo smallint DEFAULT (1)::smallint NOT NULL
);


--
-- Name: dispensa_disciplina_cod_dispensa_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.dispensa_disciplina_cod_dispensa_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dispensa_disciplina; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.dispensa_disciplina (
    ref_cod_matricula integer NOT NULL,
    ref_cod_disciplina integer NOT NULL,
    ref_cod_escola integer NOT NULL,
    ref_cod_serie integer NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    ref_cod_tipo_dispensa integer NOT NULL,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    observacao text,
    cod_dispensa integer DEFAULT nextval('pmieducar.dispensa_disciplina_cod_dispensa_seq'::regclass) NOT NULL,
    updated_at timestamp without time zone DEFAULT now(),
    batch boolean DEFAULT false NOT NULL
);


--
-- Name: dispensa_disciplina_excluidos; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.dispensa_disciplina_excluidos (
    cod_dispensa integer NOT NULL,
    ref_cod_matricula integer NOT NULL,
    ref_cod_disciplina integer NOT NULL,
    ref_cod_escola integer NOT NULL,
    ref_cod_serie integer NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    ref_cod_tipo_dispensa integer NOT NULL,
    data_cadastro timestamp(0) without time zone NOT NULL,
    data_exclusao timestamp(0) without time zone,
    ativo integer NOT NULL,
    observacao text,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    deleted_at timestamp(0) without time zone
);


--
-- Name: dispensa_etapa; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.dispensa_etapa (
    ref_cod_dispensa integer,
    etapa integer
);


--
-- Name: distribuicao_uniforme_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.distribuicao_uniforme_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: escola_cod_escola_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.escola_cod_escola_seq
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: escola; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.escola (
    cod_escola integer DEFAULT nextval('pmieducar.escola_cod_escola_seq'::regclass) NOT NULL,
    ref_usuario_cad integer NOT NULL,
    ref_usuario_exc integer,
    ref_cod_instituicao integer NOT NULL,
    ref_idpes integer,
    sigla character varying(20) NOT NULL,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    bloquear_lancamento_diario_anos_letivos_encerrados integer,
    situacao_funcionamento integer DEFAULT 1,
    dependencia_administrativa integer DEFAULT 3,
    regulamentacao integer DEFAULT 1,
    longitude character varying(20),
    latitude character varying(20),
    acesso integer,
    ref_idpes_gestor integer,
    cargo_gestor integer,
    local_funcionamento integer[],
    condicao integer DEFAULT 1,
    codigo_inep_escola_compartilhada integer,
    decreto_criacao character varying(50),
    area_terreno_total character varying(10),
    area_construida character varying(10),
    area_disponivel character varying(10),
    num_pavimentos integer,
    tipo_piso integer,
    medidor_energia integer,
    agua_consumida integer,
    dependencia_sala_diretoria integer,
    dependencia_sala_professores integer,
    dependencia_sala_secretaria integer,
    dependencia_laboratorio_informatica integer,
    dependencia_laboratorio_ciencias integer,
    dependencia_sala_aee integer,
    dependencia_quadra_coberta integer,
    dependencia_quadra_descoberta integer,
    dependencia_cozinha integer,
    dependencia_biblioteca integer,
    dependencia_sala_leitura integer,
    dependencia_parque_infantil integer,
    dependencia_bercario integer,
    dependencia_banheiro_fora integer,
    dependencia_banheiro_dentro integer,
    dependencia_banheiro_infantil integer,
    dependencia_banheiro_deficiente integer,
    dependencia_banheiro_chuveiro integer,
    dependencia_refeitorio integer,
    dependencia_dispensa integer,
    dependencia_aumoxarifado integer,
    dependencia_auditorio integer,
    dependencia_patio_coberto integer,
    dependencia_patio_descoberto integer,
    dependencia_alojamento_aluno integer,
    dependencia_alojamento_professor integer,
    dependencia_area_verde integer,
    dependencia_lavanderia integer,
    dependencia_unidade_climatizada integer,
    dependencia_quantidade_ambiente_climatizado integer,
    dependencia_nenhuma_relacionada integer,
    dependencia_numero_salas_existente integer,
    dependencia_numero_salas_utilizadas integer,
    porte_quadra_descoberta integer,
    porte_quadra_coberta integer,
    tipo_cobertura_patio integer,
    total_funcionario integer,
    atendimento_aee integer DEFAULT 0,
    atividade_complementar integer DEFAULT 0,
    fundamental_ciclo integer,
    localizacao_diferenciada integer DEFAULT 7,
    didatico_nao_utiliza integer,
    didatico_quilombola integer,
    didatico_indigena integer,
    educacao_indigena integer,
    lingua_ministrada integer,
    espaco_brasil_aprendizado integer,
    abre_final_semana integer,
    codigo_lingua_indigena integer[],
    proposta_pedagogica integer,
    televisoes smallint,
    videocassetes smallint,
    dvds smallint,
    antenas_parabolicas smallint,
    copiadoras smallint,
    retroprojetores smallint,
    impressoras smallint,
    aparelhos_de_som smallint,
    projetores_digitais smallint,
    faxs smallint,
    maquinas_fotograficas smallint,
    computadores smallint,
    computadores_administrativo smallint,
    computadores_alunos smallint,
    acesso_internet smallint,
    ato_criacao character varying(255),
    dependencia_vias_deficiente smallint,
    utiliza_regra_diferenciada boolean,
    ato_autorizativo character varying(255),
    ref_idpes_secretario_escolar integer,
    impressoras_multifuncionais smallint,
    categoria_escola_privada integer,
    conveniada_com_poder_publico integer,
    cnpj_mantenedora_principal numeric(14,0),
    mantenedora_escola_privada integer[],
    materiais_didaticos_especificos integer,
    abastecimento_agua integer[],
    abastecimento_energia integer[],
    esgoto_sanitario integer[],
    destinacao_lixo integer[],
    email_gestor character varying(255),
    zona_localizacao smallint,
    codigo_inep_escola_compartilhada2 integer,
    codigo_inep_escola_compartilhada3 integer,
    codigo_inep_escola_compartilhada4 integer,
    codigo_inep_escola_compartilhada5 integer,
    codigo_inep_escola_compartilhada6 integer,
    orgao_vinculado_escola integer[],
    esfera_administrativa integer,
    unidade_vinculada_outra_instituicao integer,
    inep_escola_sede integer,
    codigo_ies integer,
    predio_compartilhado_outra_escola integer,
    agua_potavel_consumo integer,
    tratamento_lixo integer[],
    salas_gerais integer[],
    salas_funcionais integer[],
    banheiros integer[],
    laboratorios integer[],
    salas_atividades integer[],
    dormitorios integer[],
    areas_externas integer[],
    recursos_acessibilidade integer[],
    possui_dependencias integer,
    numero_salas_utilizadas_dentro_predio integer,
    numero_salas_utilizadas_fora_predio integer,
    numero_salas_climatizadas integer,
    numero_salas_acessibilidade integer,
    qtd_secretario_escolar integer,
    qtd_auxiliar_administrativo integer,
    qtd_apoio_pedagogico integer,
    qtd_coordenador_turno integer,
    qtd_tecnicos integer,
    qtd_bibliotecarios integer,
    qtd_segurancas integer,
    qtd_auxiliar_servicos_gerais integer,
    qtd_nutricionistas integer,
    qtd_profissionais_preparacao integer,
    qtd_bombeiro integer,
    qtd_psicologo integer,
    qtd_fonoaudiologo integer,
    alimentacao_escolar_alunos integer,
    compartilha_espacos_atividades_integracao integer,
    usa_espacos_equipamentos_atividades_regulares integer,
    equipamentos integer[],
    uso_internet integer[],
    rede_local integer[],
    equipamentos_acesso_internet integer[],
    quantidade_computadores_alunos_mesa integer,
    quantidade_computadores_alunos_portateis integer,
    quantidade_computadores_alunos_tablets integer,
    lousas_digitais integer,
    organizacao_ensino integer[],
    instrumentos_pedagogicos integer[],
    orgaos_colegiados integer[],
    exame_selecao_ingresso integer,
    reserva_vagas_cotas integer[],
    projeto_politico_pedagogico integer,
    updated_at timestamp without time zone DEFAULT now(),
    iddis integer,
    qtd_vice_diretor integer,
    qtd_orientador_comunitario integer,
    poder_publico_parceria_convenio smallint[],
    formas_contratacao_adm_publica_e_outras_instituicoes smallint[],
    nao_ha_funcionarios_para_funcoes boolean DEFAULT false NOT NULL,
    qtd_matriculas_atividade_complementar integer,
    qtd_atendimento_educacional_especializado integer,
    qtd_ensino_regular_creche_par integer,
    qtd_ensino_regular_creche_int integer,
    qtd_ensino_regular_pre_escola_par integer,
    qtd_ensino_regular_pre_escola_int integer,
    qtd_ensino_regular_ensino_fund_anos_iniciais_par integer,
    qtd_ensino_regular_ensino_fund_anos_iniciais_int integer,
    qtd_ensino_regular_ensino_fund_anos_finais_par integer,
    qtd_ensino_regular_ensino_fund_anos_finais_int integer,
    qtd_ensino_regular_ensino_med_anos_iniciais_par integer,
    qtd_ensino_regular_ensino_med_anos_iniciais_int integer,
    qtd_edu_especial_classe_especial_par integer,
    qtd_edu_especial_classe_especial_int integer,
    qtd_edu_eja_ensino_fund integer,
    qtd_edu_eja_ensino_med integer,
    qtd_edu_prof_quali_prof_inte_edu_eja_no_ensino_fund_par integer,
    qtd_edu_prof_quali_prof_inte_edu_eja_no_ensino_fund_int integer,
    qtd_edu_prof_quali_prof_tec_inte_edu_eja_nivel_med_par integer,
    qtd_edu_prof_quali_prof_tec_inte_edu_eja_nivel_med_int integer,
    qtd_edu_prof_quali_prof_tec_conc_edu_eja_nivel_med_par integer,
    qtd_edu_prof_quali_prof_tec_conc_edu_eja_nivel_med_int integer,
    qtd_edu_prof_quali_prof_tec_conc_inter_edu_eja_nivel_med_par integer,
    qtd_edu_prof_quali_prof_tec_conc_inter_edu_eja_nivel_med_int integer,
    qtd_edu_prof_quali_prof_tec_inte_ensino_med_par integer,
    qtd_edu_prof_quali_prof_tecinte_ensino_med_int integer,
    qtd_edu_prof_quali_prof_tec_conc_ensino_med_par integer,
    qtd_edu_prof_quali_prof_tec_conc_ensino_med_int integer,
    qtd_edu_prof_quali_prof_tec_conc_inter_ensino_med_par integer,
    qtd_edu_prof_quali_prof_tec_conc_inter_ensino_med_int integer,
    qtd_edu_prof_edu_prof_tec_nivel_med_inte_edu_eja_nivel_med_par integer,
    qtd_edu_prof_edu_prof_tec_nivel_med_inte_edu_eja_nivel_med_int integer,
    qtd_edu_prof_edu_prof_tec_nivel_med_conc_edu_eja_nivel_med_par integer,
    qtd_edu_prof_edu_prof_tec_nivel_med_conc_edu_eja_nivel_med_int integer,
    qtd_edu_prof_edu_prof_tec_nivel_med_conc_inter_edu_eja_med_par integer,
    qtd_edu_prof_edu_prof_tec_nivel_med_conc_inter_edu_eja_med_int integer,
    qtd_edu_prof_edu_prof_tec_nivel_med_inte_ensino_med_par integer,
    qtd_edu_prof_edu_prof_tec_nivel_med_inte_ensino_med_int integer,
    qtd_edu_prof_edu_prof_tec_nivel_med_conc_ensino_med_par integer,
    qtd_edu_prof_edu_prof_tec_nivel_med_subsequente_ensino_med integer,
    qtd_edu_prof_edu_prof_tec_nivel_med_conc_ensino_med_int integer,
    qtd_edu_prof_edu_prof_tec_nivel_med_conc_inter_ensino_med_par integer,
    qtd_edu_prof_edu_prof_tec_nivel_med_conc_inter_ensino_med_int integer,
    qtd_tradutor_interprete_libras_outro_ambiente integer,
    formas_contratacao_parceria_escola_secretaria_estadual smallint[],
    formas_contratacao_parceria_escola_secretaria_municipal smallint[],
    qtd_agronomos_horticultores smallint,
    qtd_revisor_braile smallint,
    acao_area_ambiental smallint,
    acoes_area_ambiental smallint[],
    caracteristica_escolar smallint,
    lei_conclusao_ensino_medio character varying(191),
    numero_salas_cantinho_leitura integer
);


--
-- Name: escola_ano_letivo; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.escola_ano_letivo (
    ref_cod_escola integer NOT NULL,
    ano integer NOT NULL,
    ref_usuario_cad integer NOT NULL,
    ref_usuario_exc integer,
    andamento smallint DEFAULT (0)::smallint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    turmas_por_ano smallint,
    copia_dados_professor boolean DEFAULT false NOT NULL,
    copia_dados_demais_servidores boolean DEFAULT false NOT NULL,
    id integer NOT NULL,
    updated_at timestamp(0) without time zone,
    copia_turmas boolean DEFAULT true NOT NULL
);


--
-- Name: escola_ano_letivo_id_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.escola_ano_letivo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: escola_ano_letivo_id_seq; Type: SEQUENCE OWNED BY; Schema: pmieducar; Owner: -
--

ALTER SEQUENCE pmieducar.escola_ano_letivo_id_seq OWNED BY pmieducar.escola_ano_letivo.id;


--
-- Name: escola_complemento; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.escola_complemento (
    ref_cod_escola integer NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    cep numeric(8,0) NOT NULL,
    numero numeric(10,0),
    complemento character varying(50),
    email character varying(50),
    nm_escola character varying(255) NOT NULL,
    municipio character varying(60) NOT NULL,
    bairro character varying(40) NOT NULL,
    logradouro character varying(150) NOT NULL,
    ddd_telefone numeric(2,0),
    telefone numeric(11,0),
    ddd_fax numeric(2,0),
    fax numeric(11,0),
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL
);


--
-- Name: escola_curso; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.escola_curso (
    ref_cod_escola integer NOT NULL,
    ref_cod_curso integer NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    autorizacao character varying(255),
    anos_letivos smallint[] DEFAULT '{}'::smallint[] NOT NULL,
    updated_at timestamp without time zone DEFAULT now()
);


--
-- Name: escola_localizacao_cod_escola_localizacao_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.escola_localizacao_cod_escola_localizacao_seq
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: escola_localizacao; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.escola_localizacao (
    cod_escola_localizacao integer DEFAULT nextval('pmieducar.escola_localizacao_cod_escola_localizacao_seq'::regclass) NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    nm_localizacao character varying(255) NOT NULL,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    ref_cod_instituicao integer NOT NULL
);


--
-- Name: escola_serie; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.escola_serie (
    ref_cod_escola integer NOT NULL,
    ref_cod_serie integer NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    hora_inicial time without time zone,
    hora_final time without time zone,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    hora_inicio_intervalo time without time zone,
    hora_fim_intervalo time without time zone,
    bloquear_enturmacao_sem_vagas integer,
    bloquear_cadastro_turma_para_serie_com_vagas integer,
    anos_letivos smallint[] DEFAULT '{}'::smallint[] NOT NULL,
    updated_at timestamp without time zone DEFAULT now()
);


--
-- Name: escola_serie_disciplina; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.escola_serie_disciplina (
    id integer NOT NULL,
    ref_ref_cod_serie integer NOT NULL,
    ref_ref_cod_escola integer NOT NULL,
    ref_cod_disciplina integer NOT NULL,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    carga_horaria numeric(7,3),
    etapas_especificas smallint,
    etapas_utilizadas character varying,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    anos_letivos smallint[] DEFAULT '{}'::smallint[] NOT NULL,
    hora_falta numeric(7,4),
    aulas_por_semana smallint
);


--
-- Name: escola_serie_disciplina_excluidos; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.escola_serie_disciplina_excluidos (
    id integer NOT NULL,
    ref_ref_cod_serie integer NOT NULL,
    ref_ref_cod_escola integer NOT NULL,
    ref_cod_disciplina integer NOT NULL,
    ativo integer NOT NULL,
    carga_horaria integer,
    etapas_especificas integer,
    etapas_utilizadas character varying(191),
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    deleted_at timestamp(0) without time zone,
    anos_letivos smallint[] DEFAULT '{}'::smallint[] NOT NULL
);


--
-- Name: escola_serie_disciplina_excluidos_id_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.escola_serie_disciplina_excluidos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: escola_serie_disciplina_excluidos_id_seq; Type: SEQUENCE OWNED BY; Schema: pmieducar; Owner: -
--

ALTER SEQUENCE pmieducar.escola_serie_disciplina_excluidos_id_seq OWNED BY pmieducar.escola_serie_disciplina_excluidos.id;


--
-- Name: escola_serie_disciplina_id_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.escola_serie_disciplina_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: escola_serie_disciplina_id_seq; Type: SEQUENCE OWNED BY; Schema: pmieducar; Owner: -
--

ALTER SEQUENCE pmieducar.escola_serie_disciplina_id_seq OWNED BY pmieducar.escola_serie_disciplina.id;


--
-- Name: escola_usuario; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.escola_usuario (
    id integer NOT NULL,
    ref_cod_usuario integer NOT NULL,
    ref_cod_escola integer NOT NULL,
    escola_atual integer
);


--
-- Name: escola_usuario_id_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.escola_usuario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: escola_usuario_id_seq; Type: SEQUENCE OWNED BY; Schema: pmieducar; Owner: -
--

ALTER SEQUENCE pmieducar.escola_usuario_id_seq OWNED BY pmieducar.escola_usuario.id;


--
-- Name: falta_atraso_cod_falta_atraso_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.falta_atraso_cod_falta_atraso_seq
    START WITH 1
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: falta_atraso; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.falta_atraso (
    cod_falta_atraso integer DEFAULT nextval('pmieducar.falta_atraso_cod_falta_atraso_seq'::regclass) NOT NULL,
    ref_cod_escola integer NOT NULL,
    ref_ref_cod_instituicao integer NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    ref_cod_servidor integer NOT NULL,
    tipo smallint NOT NULL,
    data_falta_atraso timestamp without time zone NOT NULL,
    qtd_horas integer,
    qtd_min integer,
    justificada smallint DEFAULT (0)::smallint NOT NULL,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    ref_cod_servidor_funcao integer
);


--
-- Name: falta_atraso_compensado_cod_compensado_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.falta_atraso_compensado_cod_compensado_seq
    START WITH 1
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: falta_atraso_compensado; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.falta_atraso_compensado (
    cod_compensado integer DEFAULT nextval('pmieducar.falta_atraso_compensado_cod_compensado_seq'::regclass) NOT NULL,
    ref_cod_escola integer NOT NULL,
    ref_ref_cod_instituicao integer NOT NULL,
    ref_cod_servidor integer NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    data_inicio timestamp without time zone NOT NULL,
    data_fim timestamp without time zone NOT NULL,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL
);


--
-- Name: funcao_cod_funcao_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.funcao_cod_funcao_seq
    START WITH 1
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: funcao; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.funcao (
    cod_funcao integer DEFAULT nextval('pmieducar.funcao_cod_funcao_seq'::regclass) NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    nm_funcao character varying(255) NOT NULL,
    abreviatura character varying(30) NOT NULL,
    professor smallint DEFAULT (0)::smallint NOT NULL,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    ref_cod_instituicao integer NOT NULL
);


--
-- Name: historico_disciplinas; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.historico_disciplinas (
    id integer NOT NULL,
    sequencial integer NOT NULL,
    ref_ref_cod_aluno integer NOT NULL,
    ref_sequencial integer NOT NULL,
    nm_disciplina text NOT NULL,
    nota character varying(255) NOT NULL,
    faltas integer,
    import numeric(1,0),
    ordenamento integer,
    carga_horaria_disciplina integer,
    dependencia boolean DEFAULT false,
    tipo_base integer DEFAULT 1 NOT NULL
);


--
-- Name: historico_disciplinas_id_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.historico_disciplinas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: historico_disciplinas_id_seq; Type: SEQUENCE OWNED BY; Schema: pmieducar; Owner: -
--

ALTER SEQUENCE pmieducar.historico_disciplinas_id_seq OWNED BY pmieducar.historico_disciplinas.id;


--
-- Name: historico_escolar; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.historico_escolar (
    id integer NOT NULL,
    ref_cod_aluno integer NOT NULL,
    sequencial integer NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    ano integer NOT NULL,
    carga_horaria double precision,
    dias_letivos integer,
    escola character varying(255) NOT NULL,
    escola_cidade character varying(255) NOT NULL,
    escola_uf character varying(3),
    observacao text,
    aprovado smallint DEFAULT (1)::smallint NOT NULL,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    faltas_globalizadas integer,
    nm_serie character varying(255),
    origem smallint DEFAULT (1)::smallint,
    extra_curricular smallint DEFAULT (0)::smallint,
    ref_cod_matricula integer,
    ref_cod_instituicao integer,
    import numeric(1,0),
    frequencia numeric(5,2) DEFAULT 0.000,
    registro character varying(50),
    livro character varying(50),
    folha character varying(50),
    historico_grade_curso_id integer,
    nm_curso character varying(255),
    aceleracao integer,
    ref_cod_escola integer,
    dependencia boolean,
    posicao integer
);


--
-- Name: historico_escolar_id_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.historico_escolar_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: historico_escolar_id_seq; Type: SEQUENCE OWNED BY; Schema: pmieducar; Owner: -
--

ALTER SEQUENCE pmieducar.historico_escolar_id_seq OWNED BY pmieducar.historico_escolar.id;


--
-- Name: historico_grade_curso_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.historico_grade_curso_seq
    START WITH 3
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: historico_grade_curso; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.historico_grade_curso (
    id integer DEFAULT nextval('pmieducar.historico_grade_curso_seq'::regclass) NOT NULL,
    descricao_etapa character varying(20) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone,
    quantidade_etapas integer,
    ativo smallint DEFAULT (1)::smallint NOT NULL
);


--
-- Name: instituicao_cod_instituicao_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.instituicao_cod_instituicao_seq
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: instituicao; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.instituicao (
    cod_instituicao integer DEFAULT nextval('pmieducar.instituicao_cod_instituicao_seq'::regclass) NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    ref_idtlog character varying(20) NOT NULL,
    ref_sigla_uf character(2) NOT NULL,
    cep numeric(8,0) NOT NULL,
    cidade character varying(60) NOT NULL,
    bairro character varying(40) NOT NULL,
    logradouro character varying(255) NOT NULL,
    numero numeric(6,0),
    complemento character varying(50),
    nm_responsavel character varying(255) NOT NULL,
    ddd_telefone numeric(2,0),
    telefone numeric(11,0),
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    nm_instituicao character varying(255) NOT NULL,
    data_base_remanejamento date,
    data_base_transferencia date,
    controlar_espaco_utilizacao_aluno smallint,
    percentagem_maxima_ocupacao_salas numeric(5,2),
    quantidade_alunos_metro_quadrado integer,
    exigir_vinculo_turma_professor smallint,
    gerar_historico_transferencia boolean,
    matricula_apenas_bairro_escola boolean,
    restringir_historico_escolar boolean,
    coordenador_transporte character varying,
    restringir_multiplas_enturmacoes boolean,
    permissao_filtro_abandono_transferencia boolean,
    data_base_matricula date,
    multiplas_reserva_vaga boolean DEFAULT false NOT NULL,
    reserva_integral_somente_com_renda boolean DEFAULT false NOT NULL,
    data_expiracao_reserva_vaga date,
    data_fechamento date,
    componente_curricular_turma boolean,
    reprova_dependencia_ano_concluinte boolean,
    controlar_posicao_historicos boolean,
    data_educacenso date,
    bloqueia_matricula_serie_nao_seguinte boolean,
    permitir_carga_horaria boolean DEFAULT false,
    exigir_dados_socioeconomicos boolean DEFAULT false,
    altera_atestado_para_declaracao boolean,
    orgao_regional character varying(5),
    obrigar_campos_censo boolean,
    obrigar_documento_pessoa boolean DEFAULT false,
    exigir_lancamentos_anteriores boolean DEFAULT false,
    exibir_apenas_professores_alocados boolean DEFAULT false,
    bloquear_vinculo_professor_sem_alocacao_escola boolean DEFAULT false NOT NULL,
    permitir_matricula_fora_periodo_letivo boolean DEFAULT false NOT NULL,
    ordenar_alunos_sequencial_enturmacao boolean DEFAULT false NOT NULL,
    obrigar_telefone_pessoa boolean,
    obrigar_cpf boolean DEFAULT false NOT NULL
);


--
-- Name: instituicao_documentacao_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.instituicao_documentacao_seq
    START WITH 2
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: instituicao_documentacao; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.instituicao_documentacao (
    id integer DEFAULT nextval('pmieducar.instituicao_documentacao_seq'::regclass) NOT NULL,
    instituicao_id integer NOT NULL,
    titulo_documento character varying(100) NOT NULL,
    url_documento character varying(255) NOT NULL,
    ref_usuario_cad integer DEFAULT 0 NOT NULL,
    ref_cod_escola integer
);


--
-- Name: matricula_cod_matricula_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.matricula_cod_matricula_seq
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: matricula; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.matricula (
    cod_matricula integer DEFAULT nextval('pmieducar.matricula_cod_matricula_seq'::regclass) NOT NULL,
    ref_ref_cod_escola integer,
    ref_ref_cod_serie integer,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    ref_cod_aluno integer NOT NULL,
    aprovado smallint DEFAULT (0)::smallint NOT NULL,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    ano integer NOT NULL,
    ultima_matricula smallint DEFAULT (0)::smallint NOT NULL,
    modulo smallint DEFAULT 1 NOT NULL,
    descricao_reclassificacao text,
    formando smallint DEFAULT (0)::smallint NOT NULL,
    matricula_reclassificacao smallint DEFAULT (0)::smallint,
    ref_cod_curso integer,
    matricula_transferencia boolean DEFAULT false NOT NULL,
    semestre smallint,
    observacao character varying(300),
    data_matricula timestamp without time zone,
    data_cancel timestamp without time zone,
    ref_cod_abandono_tipo integer,
    turno_pre_matricula smallint,
    dependencia boolean DEFAULT false,
    saida_escola boolean DEFAULT false,
    data_saida_escola date,
    updated_at timestamp without time zone DEFAULT now(),
    observacoes text,
    modalidade_ensino smallint DEFAULT '3'::smallint NOT NULL,
    bloquear_troca_de_situacao boolean DEFAULT false NOT NULL,
    deixou_de_frequentar_idade_obrigatoria boolean DEFAULT false NOT NULL
);


--
-- Name: ocorrencia_disciplinar_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.ocorrencia_disciplinar_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: matricula_ocorrencia_disciplinar; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.matricula_ocorrencia_disciplinar (
    ref_cod_matricula integer NOT NULL,
    ref_cod_tipo_ocorrencia_disciplinar integer NOT NULL,
    sequencial integer NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    observacao text NOT NULL,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    visivel_pais integer,
    cod_ocorrencia_disciplinar integer DEFAULT nextval('pmieducar.ocorrencia_disciplinar_seq'::regclass) NOT NULL,
    updated_at timestamp without time zone DEFAULT now()
);


--
-- Name: matricula_turma; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.matricula_turma (
    ref_cod_matricula integer NOT NULL,
    ref_cod_turma integer NOT NULL,
    sequencial integer NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    data_enturmacao date NOT NULL,
    sequencial_fechamento integer DEFAULT 0 NOT NULL,
    transferido boolean,
    remanejado boolean,
    reclassificado boolean,
    abandono boolean,
    falecido boolean,
    etapa_educacenso smallint,
    turma_unificada smallint,
    turno_id integer,
    id integer NOT NULL,
    tipo_atendimento integer[],
    updated_at timestamp(0) without time zone DEFAULT now(),
    remanejado_mesma_turma boolean DEFAULT false NOT NULL,
    tipo_itinerario smallint[],
    composicao_itinerario smallint[],
    curso_itinerario integer,
    itinerario_concomitante boolean,
    cod_curso_profissional integer,
    desconsiderar_educacenso boolean DEFAULT false NOT NULL
);


--
-- Name: matricula_turma_excluidos; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.matricula_turma_excluidos (
    id integer NOT NULL,
    ref_cod_matricula integer NOT NULL,
    ref_cod_turma integer NOT NULL,
    sequencial integer NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    data_cadastro timestamp(0) without time zone NOT NULL,
    data_exclusao timestamp(0) without time zone,
    ativo smallint NOT NULL,
    data_enturmacao date NOT NULL,
    sequencial_fechamento integer NOT NULL,
    transferido boolean,
    remanejado boolean,
    reclassificado boolean,
    abandono boolean,
    falecido boolean,
    etapa_educacenso smallint,
    turma_unificada smallint,
    turno_id integer,
    updated_at timestamp(0) without time zone,
    deleted_at timestamp(0) without time zone
);


--
-- Name: matricula_turma_excluidos_id_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.matricula_turma_excluidos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: matricula_turma_excluidos_id_seq; Type: SEQUENCE OWNED BY; Schema: pmieducar; Owner: -
--

ALTER SEQUENCE pmieducar.matricula_turma_excluidos_id_seq OWNED BY pmieducar.matricula_turma_excluidos.id;


--
-- Name: matricula_turma_id_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.matricula_turma_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: matricula_turma_id_seq; Type: SEQUENCE OWNED BY; Schema: pmieducar; Owner: -
--

ALTER SEQUENCE pmieducar.matricula_turma_id_seq OWNED BY pmieducar.matricula_turma.id;


--
-- Name: menu_tipo_usuario; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.menu_tipo_usuario (
    ref_cod_tipo_usuario integer NOT NULL,
    menu_id integer NOT NULL,
    cadastra smallint DEFAULT 0 NOT NULL,
    visualiza smallint DEFAULT 0 NOT NULL,
    exclui smallint DEFAULT 0 NOT NULL
);


--
-- Name: modulo_cod_modulo_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.modulo_cod_modulo_seq
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: modulo; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.modulo (
    cod_modulo smallint DEFAULT nextval('pmieducar.modulo_cod_modulo_seq'::regclass) NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    nm_tipo character varying(255) NOT NULL,
    descricao text,
    num_meses smallint,
    num_semanas smallint,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    ref_cod_instituicao integer NOT NULL,
    num_etapas smallint DEFAULT '0'::smallint
);


--
-- Name: motivo_afastamento_cod_motivo_afastamento_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.motivo_afastamento_cod_motivo_afastamento_seq
    START WITH 1
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: motivo_afastamento; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.motivo_afastamento (
    cod_motivo_afastamento integer DEFAULT nextval('pmieducar.motivo_afastamento_cod_motivo_afastamento_seq'::regclass) NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    nm_motivo character varying(255) NOT NULL,
    descricao text,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    ref_cod_instituicao integer NOT NULL
);


--
-- Name: nivel_ensino_cod_nivel_ensino_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.nivel_ensino_cod_nivel_ensino_seq
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: nivel_ensino; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.nivel_ensino (
    cod_nivel_ensino integer DEFAULT nextval('pmieducar.nivel_ensino_cod_nivel_ensino_seq'::regclass) NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    nm_nivel character varying(255) NOT NULL,
    descricao text,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    ref_cod_instituicao integer NOT NULL
);


--
-- Name: projeto_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.projeto_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: projeto; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.projeto (
    cod_projeto integer DEFAULT nextval('pmieducar.projeto_seq'::regclass) NOT NULL,
    nome character varying(50),
    observacao text NOT NULL
);


--
-- Name: projeto_aluno; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.projeto_aluno (
    ref_cod_projeto integer NOT NULL,
    ref_cod_aluno integer NOT NULL,
    data_inclusao date,
    data_desligamento date,
    turno integer,
    id integer NOT NULL
);


--
-- Name: projeto_aluno_id_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.projeto_aluno_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: projeto_aluno_id_seq; Type: SEQUENCE OWNED BY; Schema: pmieducar; Owner: -
--

ALTER SEQUENCE pmieducar.projeto_aluno_id_seq OWNED BY pmieducar.projeto_aluno.id;


--
-- Name: quadro_horario_cod_quadro_horario_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.quadro_horario_cod_quadro_horario_seq
    START WITH 1
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: quadro_horario; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.quadro_horario (
    cod_quadro_horario integer DEFAULT nextval('pmieducar.quadro_horario_cod_quadro_horario_seq'::regclass) NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    ref_cod_turma integer NOT NULL,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    ano integer
);


--
-- Name: quadro_horario_horarios; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.quadro_horario_horarios (
    ref_cod_quadro_horario integer NOT NULL,
    sequencial integer NOT NULL,
    ref_cod_disciplina integer NOT NULL,
    ref_cod_escola integer NOT NULL,
    ref_cod_serie integer NOT NULL,
    ref_cod_instituicao_substituto integer,
    ref_cod_instituicao_servidor integer NOT NULL,
    ref_servidor_substituto integer,
    ref_servidor integer NOT NULL,
    dia_semana integer NOT NULL,
    hora_inicial time without time zone NOT NULL,
    hora_final time without time zone NOT NULL,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL
);


--
-- Name: quadro_horario_horarios_aux; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.quadro_horario_horarios_aux (
    ref_cod_quadro_horario integer NOT NULL,
    sequencial integer NOT NULL,
    ref_cod_disciplina integer NOT NULL,
    ref_cod_escola integer NOT NULL,
    ref_cod_serie integer NOT NULL,
    ref_cod_instituicao_servidor integer NOT NULL,
    ref_servidor integer NOT NULL,
    dia_semana integer NOT NULL,
    hora_inicial time without time zone NOT NULL,
    hora_final time without time zone NOT NULL,
    identificador character varying(30),
    data_cadastro timestamp without time zone NOT NULL
);


--
-- Name: religiao_cod_religiao_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.religiao_cod_religiao_seq
    START WITH 1
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: religions; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.religions (
    id integer DEFAULT nextval('pmieducar.religiao_cod_religiao_seq'::regclass) NOT NULL,
    name character varying(255) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone,
    deleted_at timestamp without time zone
);


--
-- Name: reserva_vaga_cod_reserva_vaga_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.reserva_vaga_cod_reserva_vaga_seq
    START WITH 1
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: sequencia_serie; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.sequencia_serie (
    ref_serie_origem integer NOT NULL,
    ref_serie_destino integer NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    id integer NOT NULL,
    updated_at timestamp(0) without time zone
);


--
-- Name: sequencia_serie_id_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.sequencia_serie_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sequencia_serie_id_seq; Type: SEQUENCE OWNED BY; Schema: pmieducar; Owner: -
--

ALTER SEQUENCE pmieducar.sequencia_serie_id_seq OWNED BY pmieducar.sequencia_serie.id;


--
-- Name: serie_cod_serie_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.serie_cod_serie_seq
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: serie; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.serie (
    cod_serie integer DEFAULT nextval('pmieducar.serie_cod_serie_seq'::regclass) NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    ref_cod_curso integer NOT NULL,
    nm_serie character varying(255) NOT NULL,
    etapa_curso integer NOT NULL,
    concluinte smallint DEFAULT (0)::smallint NOT NULL,
    carga_horaria double precision NOT NULL,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    intervalo integer,
    idade_inicial numeric(3,0),
    idade_final numeric(3,0),
    regra_avaliacao_id integer,
    observacao_historico text,
    dias_letivos integer,
    regra_avaliacao_diferenciada_id integer,
    alerta_faixa_etaria boolean,
    bloquear_matricula_faixa_etaria boolean,
    idade_ideal integer,
    exigir_inep boolean,
    updated_at timestamp without time zone DEFAULT now(),
    importar_serie_pre_matricula boolean DEFAULT false NOT NULL,
    descricao character varying(50),
    etapa_educacenso smallint
);


--
-- Name: servidor; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.servidor (
    cod_servidor integer NOT NULL,
    ref_cod_instituicao integer NOT NULL,
    ref_idesco numeric(2,0),
    carga_horaria double precision NOT NULL,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    situacao_curso_superior_1 smallint,
    formacao_complementacao_pedagogica_1 smallint,
    codigo_curso_superior_1 integer,
    ano_inicio_curso_superior_1 numeric(4,0),
    ano_conclusao_curso_superior_1 numeric(4,0),
    instituicao_curso_superior_1 smallint,
    situacao_curso_superior_2 smallint,
    formacao_complementacao_pedagogica_2 smallint,
    codigo_curso_superior_2 integer,
    ano_inicio_curso_superior_2 numeric(4,0),
    ano_conclusao_curso_superior_2 numeric(4,0),
    instituicao_curso_superior_2 smallint,
    situacao_curso_superior_3 smallint,
    formacao_complementacao_pedagogica_3 smallint,
    codigo_curso_superior_3 integer,
    ano_inicio_curso_superior_3 numeric(4,0),
    ano_conclusao_curso_superior_3 numeric(4,0),
    instituicao_curso_superior_3 smallint,
    multi_seriado boolean,
    pos_graduacao integer[],
    curso_formacao_continuada integer[],
    tipo_ensino_medio_cursado integer,
    updated_at timestamp without time zone DEFAULT now(),
    complementacao_pedagogica smallint[]
);


--
-- Name: servidor_afastamento; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.servidor_afastamento (
    ref_cod_servidor integer NOT NULL,
    sequencial integer NOT NULL,
    ref_ref_cod_instituicao integer NOT NULL,
    ref_cod_motivo_afastamento integer NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    data_retorno timestamp without time zone,
    data_saida timestamp without time zone NOT NULL,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    id bigint NOT NULL
);


--
-- Name: servidor_afastamento_id_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.servidor_afastamento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: servidor_afastamento_id_seq; Type: SEQUENCE OWNED BY; Schema: pmieducar; Owner: -
--

ALTER SEQUENCE pmieducar.servidor_afastamento_id_seq OWNED BY pmieducar.servidor_afastamento.id;


--
-- Name: servidor_alocacao_cod_servidor_alocacao_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.servidor_alocacao_cod_servidor_alocacao_seq
    START WITH 1
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: servidor_alocacao; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.servidor_alocacao (
    cod_servidor_alocacao integer DEFAULT nextval('pmieducar.servidor_alocacao_cod_servidor_alocacao_seq'::regclass) NOT NULL,
    ref_ref_cod_instituicao integer NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    ref_cod_escola integer NOT NULL,
    ref_cod_servidor integer NOT NULL,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    carga_horaria interval,
    periodo smallint DEFAULT (1)::smallint,
    hora_final time without time zone,
    hora_inicial time without time zone,
    dia_semana integer,
    ref_cod_servidor_funcao integer,
    ref_cod_funcionario_vinculo integer,
    ano integer,
    data_admissao date,
    hora_atividade time without time zone,
    horas_excedentes time without time zone,
    data_saida date
);


--
-- Name: servidor_curso_ministra; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.servidor_curso_ministra (
    ref_cod_curso integer NOT NULL,
    ref_ref_cod_instituicao integer NOT NULL,
    ref_cod_servidor integer NOT NULL
);


--
-- Name: servidor_disciplina; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.servidor_disciplina (
    ref_cod_disciplina integer NOT NULL,
    ref_ref_cod_instituicao integer NOT NULL,
    ref_cod_servidor integer NOT NULL,
    ref_cod_curso integer NOT NULL,
    ref_cod_funcao integer NOT NULL
);


--
-- Name: servidor_frequencia; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.servidor_frequencia (
    id bigint NOT NULL,
    servidor_id integer NOT NULL,
    data date NOT NULL,
    status character varying(255) NOT NULL,
    observacao text,
    registrado_por_usuario_id bigint NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    CONSTRAINT servidor_frequencia_status_check CHECK (((status)::text = ANY ((ARRAY['Presente'::character varying, 'Falta'::character varying, 'Falta Justificada'::character varying, 'Atestado'::character varying, 'Folga'::character varying])::text[])))
);


--
-- Name: servidor_frequencia_id_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.servidor_frequencia_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: servidor_frequencia_id_seq; Type: SEQUENCE OWNED BY; Schema: pmieducar; Owner: -
--

ALTER SEQUENCE pmieducar.servidor_frequencia_id_seq OWNED BY pmieducar.servidor_frequencia.id;


--
-- Name: servidor_funcao_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.servidor_funcao_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: servidor_funcao; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.servidor_funcao (
    ref_ref_cod_instituicao integer NOT NULL,
    ref_cod_servidor integer NOT NULL,
    ref_cod_funcao integer NOT NULL,
    matricula character varying,
    cod_servidor_funcao integer DEFAULT nextval('pmieducar.servidor_funcao_seq'::regclass) NOT NULL
);


--
-- Name: tipo_autor; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.tipo_autor (
    codigo integer,
    tipo_autor character varying(255)
);


--
-- Name: tipo_dispensa_cod_tipo_dispensa_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.tipo_dispensa_cod_tipo_dispensa_seq
    START WITH 1
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: tipo_dispensa; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.tipo_dispensa (
    cod_tipo_dispensa integer DEFAULT nextval('pmieducar.tipo_dispensa_cod_tipo_dispensa_seq'::regclass) NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    nm_tipo character varying(255) NOT NULL,
    descricao text,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    ref_cod_instituicao integer NOT NULL
);


--
-- Name: tipo_ensino_cod_tipo_ensino_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.tipo_ensino_cod_tipo_ensino_seq
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: tipo_ensino; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.tipo_ensino (
    cod_tipo_ensino integer DEFAULT nextval('pmieducar.tipo_ensino_cod_tipo_ensino_seq'::regclass) NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    nm_tipo character varying(255) NOT NULL,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    ref_cod_instituicao integer NOT NULL,
    atividade_complementar boolean DEFAULT false
);


--
-- Name: tipo_ocorrencia_disciplinar_cod_tipo_ocorrencia_disciplinar_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.tipo_ocorrencia_disciplinar_cod_tipo_ocorrencia_disciplinar_seq
    START WITH 1
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: tipo_ocorrencia_disciplinar; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.tipo_ocorrencia_disciplinar (
    cod_tipo_ocorrencia_disciplinar integer DEFAULT nextval('pmieducar.tipo_ocorrencia_disciplinar_cod_tipo_ocorrencia_disciplinar_seq'::regclass) NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    nm_tipo character varying(255) NOT NULL,
    descricao text,
    max_ocorrencias integer,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    ref_cod_instituicao integer NOT NULL
);


--
-- Name: tipo_regime_cod_tipo_regime_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.tipo_regime_cod_tipo_regime_seq
    START WITH 1
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: tipo_regime; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.tipo_regime (
    cod_tipo_regime integer DEFAULT nextval('pmieducar.tipo_regime_cod_tipo_regime_seq'::regclass) NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    nm_tipo character varying(255) NOT NULL,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint NOT NULL,
    ref_cod_instituicao integer NOT NULL
);


--
-- Name: tipo_usuario_cod_tipo_usuario_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.tipo_usuario_cod_tipo_usuario_seq
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: tipo_usuario; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.tipo_usuario (
    cod_tipo_usuario integer DEFAULT nextval('pmieducar.tipo_usuario_cod_tipo_usuario_seq'::regclass) NOT NULL,
    ref_funcionario_cad integer NOT NULL,
    ref_funcionario_exc integer,
    nm_tipo character varying(255) NOT NULL,
    descricao text,
    nivel integer NOT NULL,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: transferencia_solicitacao_cod_transferencia_solicitacao_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.transferencia_solicitacao_cod_transferencia_solicitacao_seq
    START WITH 1
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: transferencia_solicitacao; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.transferencia_solicitacao (
    cod_transferencia_solicitacao integer DEFAULT nextval('pmieducar.transferencia_solicitacao_cod_transferencia_solicitacao_seq'::regclass) NOT NULL,
    ref_cod_transferencia_tipo integer NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    ref_cod_matricula_entrada integer,
    ref_cod_matricula_saida integer NOT NULL,
    observacao text,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    data_transferencia timestamp without time zone,
    ref_cod_escola_destino integer,
    escola_destino_externa character varying,
    estado_escola_destino_externa character varying(60),
    municipio_escola_destino_externa character varying(60)
);


--
-- Name: transferencia_tipo_cod_transferencia_tipo_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.transferencia_tipo_cod_transferencia_tipo_seq
    START WITH 1
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: transferencia_tipo; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.transferencia_tipo (
    cod_transferencia_tipo integer DEFAULT nextval('pmieducar.transferencia_tipo_cod_transferencia_tipo_seq'::regclass) NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    nm_tipo character varying(255) NOT NULL,
    desc_tipo text,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    ref_cod_instituicao integer
);


--
-- Name: turma_cod_turma_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.turma_cod_turma_seq
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: turma; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.turma (
    cod_turma integer DEFAULT nextval('pmieducar.turma_cod_turma_seq'::regclass) NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    ref_ref_cod_serie integer,
    ref_ref_cod_escola integer,
    nm_turma character varying(255) NOT NULL,
    sgl_turma character varying(15),
    max_aluno integer NOT NULL,
    multiseriada smallint DEFAULT (0)::smallint NOT NULL,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    ref_cod_turma_tipo integer NOT NULL,
    hora_inicial time without time zone,
    hora_final time without time zone,
    hora_inicio_intervalo time without time zone,
    hora_fim_intervalo time without time zone,
    ref_cod_regente integer,
    ref_cod_instituicao_regente integer,
    ref_cod_instituicao integer,
    ref_cod_curso integer,
    ref_ref_cod_serie_mult integer,
    ref_ref_cod_escola_mult integer,
    visivel boolean,
    tipo_boletim integer,
    turma_turno_id integer,
    ano integer,
    tipo_atendimento integer[],
    turma_mais_educacao smallint,
    atividade_complementar_1 integer,
    atividade_complementar_2 integer,
    atividade_complementar_3 integer,
    atividade_complementar_4 integer,
    atividade_complementar_5 integer,
    atividade_complementar_6 integer,
    aee_braille smallint,
    aee_recurso_optico smallint,
    aee_estrategia_desenvolvimento smallint,
    aee_tecnica_mobilidade smallint,
    aee_libras smallint,
    aee_caa smallint,
    aee_curricular smallint,
    aee_soroban smallint,
    aee_informatica smallint,
    aee_lingua_escrita smallint,
    aee_autonomia smallint,
    cod_curso_profissional integer,
    etapa_educacenso smallint,
    ref_cod_disciplina_dispensada integer,
    parecer_1_etapa text,
    parecer_2_etapa text,
    parecer_3_etapa text,
    parecer_4_etapa text,
    nao_informar_educacenso smallint,
    tipo_mediacao_didatico_pedagogico integer,
    dias_semana integer[],
    atividades_complementares integer[],
    atividades_aee integer[],
    tipo_boletim_diferenciado smallint,
    local_funcionamento_diferenciado smallint,
    updated_at timestamp without time zone DEFAULT now(),
    organizacao_curricular integer[],
    formas_organizacao_turma smallint,
    unidade_curricular smallint[],
    outras_unidades_curriculares_obrigatorias text,
    classe_com_lingua_brasileira_sinais smallint,
    hora_inicial_matutino time(0) without time zone,
    hora_inicio_intervalo_matutino time(0) without time zone,
    hora_fim_intervalo_matutino time(0) without time zone,
    hora_final_matutino time(0) without time zone,
    hora_inicial_vespertino time(0) without time zone,
    hora_inicio_intervalo_vespertino time(0) without time zone,
    hora_fim_intervalo_vespertino time(0) without time zone,
    hora_final_vespertino time(0) without time zone,
    etapa_agregada smallint,
    classe_especial smallint,
    formacao_alternancia smallint,
    area_itinerario smallint[],
    tipo_curso_intinerario smallint,
    cod_curso_profissional_intinerario smallint
);


--
-- Name: turma_modulo; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.turma_modulo (
    ref_cod_turma integer NOT NULL,
    ref_cod_modulo integer NOT NULL,
    sequencial integer NOT NULL,
    data_inicio date NOT NULL,
    data_fim date NOT NULL,
    dias_letivos integer
);


--
-- Name: turma_serie; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.turma_serie (
    id bigint NOT NULL,
    escola_id integer NOT NULL,
    serie_id integer NOT NULL,
    turma_id integer NOT NULL,
    boletim_id integer NOT NULL,
    boletim_diferenciado_id integer,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: turma_serie_id_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.turma_serie_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: turma_serie_id_seq; Type: SEQUENCE OWNED BY; Schema: pmieducar; Owner: -
--

ALTER SEQUENCE pmieducar.turma_serie_id_seq OWNED BY pmieducar.turma_serie.id;


--
-- Name: turma_tipo_cod_turma_tipo_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.turma_tipo_cod_turma_tipo_seq
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: turma_tipo; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.turma_tipo (
    cod_turma_tipo integer DEFAULT nextval('pmieducar.turma_tipo_cod_turma_tipo_seq'::regclass) NOT NULL,
    ref_usuario_exc integer,
    ref_usuario_cad integer NOT NULL,
    nm_tipo character varying(255) NOT NULL,
    sgl_tipo character varying(15) NOT NULL,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL,
    ref_cod_instituicao integer
);


--
-- Name: turma_turno_id_seq; Type: SEQUENCE; Schema: pmieducar; Owner: -
--

CREATE SEQUENCE pmieducar.turma_turno_id_seq
    START WITH 1
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: turma_turno; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.turma_turno (
    id integer DEFAULT nextval('pmieducar.turma_turno_id_seq'::regclass) NOT NULL,
    nome character varying(15) NOT NULL,
    ativo smallint DEFAULT (1)::smallint NOT NULL
);


--
-- Name: usuario; Type: TABLE; Schema: pmieducar; Owner: -
--

CREATE TABLE pmieducar.usuario (
    cod_usuario integer NOT NULL,
    ref_cod_instituicao integer,
    ref_funcionario_cad integer NOT NULL,
    ref_funcionario_exc integer,
    ref_cod_tipo_usuario integer,
    data_cadastro timestamp without time zone NOT NULL,
    data_exclusao timestamp without time zone,
    ativo smallint DEFAULT (1)::smallint NOT NULL
);


--
-- Name: acesso_cod_acesso_seq; Type: SEQUENCE; Schema: portal; Owner: -
--

CREATE SEQUENCE portal.acesso_cod_acesso_seq
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: acesso; Type: TABLE; Schema: portal; Owner: -
--

CREATE TABLE portal.acesso (
    cod_acesso integer DEFAULT nextval('portal.acesso_cod_acesso_seq'::regclass) NOT NULL,
    data_hora timestamp without time zone NOT NULL,
    ip_externo character varying(50) DEFAULT ''::character varying NOT NULL,
    ip_interno character varying(255) DEFAULT ''::character varying NOT NULL,
    cod_pessoa integer DEFAULT 0 NOT NULL,
    obs text,
    sucesso boolean DEFAULT true NOT NULL
);


--
-- Name: agenda_cod_agenda_seq; Type: SEQUENCE; Schema: portal; Owner: -
--

CREATE SEQUENCE portal.agenda_cod_agenda_seq
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: agenda; Type: TABLE; Schema: portal; Owner: -
--

CREATE TABLE portal.agenda (
    cod_agenda integer DEFAULT nextval('portal.agenda_cod_agenda_seq'::regclass) NOT NULL,
    ref_ref_cod_pessoa_exc integer,
    ref_ref_cod_pessoa_cad integer NOT NULL,
    nm_agenda character varying NOT NULL,
    publica smallint DEFAULT 0 NOT NULL,
    envia_alerta smallint DEFAULT 0 NOT NULL,
    data_cad timestamp without time zone NOT NULL,
    data_edicao timestamp without time zone,
    ref_ref_cod_pessoa_own integer
);


--
-- Name: agenda_compromisso; Type: TABLE; Schema: portal; Owner: -
--

CREATE TABLE portal.agenda_compromisso (
    cod_agenda_compromisso integer NOT NULL,
    versao integer NOT NULL,
    ref_cod_agenda integer NOT NULL,
    ref_ref_cod_pessoa_cad integer NOT NULL,
    ativo smallint DEFAULT 1,
    data_inicio timestamp without time zone,
    titulo character varying,
    descricao text,
    importante smallint DEFAULT 0 NOT NULL,
    publico smallint DEFAULT 0 NOT NULL,
    data_cadastro timestamp without time zone NOT NULL,
    data_fim timestamp without time zone
);


--
-- Name: agenda_responsavel; Type: TABLE; Schema: portal; Owner: -
--

CREATE TABLE portal.agenda_responsavel (
    ref_cod_agenda integer NOT NULL,
    ref_ref_cod_pessoa_fj integer NOT NULL,
    principal smallint
);


--
-- Name: funcionario; Type: TABLE; Schema: portal; Owner: -
--

CREATE TABLE portal.funcionario (
    ref_cod_pessoa_fj integer DEFAULT 0 NOT NULL,
    matricula character varying(12),
    senha character varying(191),
    ativo smallint,
    ref_sec integer,
    ramal character varying(10),
    sequencial character(3),
    opcao_menu text,
    ref_cod_setor integer,
    ref_cod_funcionario_vinculo integer,
    tempo_expira_senha integer,
    tempo_expira_conta integer,
    data_troca_senha date,
    data_reativa_conta date,
    ref_ref_cod_pessoa_fj integer,
    proibido integer DEFAULT 0 NOT NULL,
    ref_cod_setor_new integer,
    matricula_new bigint,
    matricula_permanente smallint DEFAULT 0,
    tipo_menu smallint DEFAULT 0 NOT NULL,
    ip_logado character varying(50),
    data_login timestamp without time zone,
    email character varying(50),
    status_token character varying(191),
    matricula_interna character varying(30),
    receber_novidades smallint,
    atualizou_cadastro smallint,
    data_expiracao date,
    force_reset_password boolean DEFAULT false NOT NULL,
    motivo text,
    data_inicial date
);


--
-- Name: funcionario_vinculo_cod_funcionario_vinculo_seq; Type: SEQUENCE; Schema: portal; Owner: -
--

CREATE SEQUENCE portal.funcionario_vinculo_cod_funcionario_vinculo_seq
    START WITH 1
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: funcionario_vinculo; Type: TABLE; Schema: portal; Owner: -
--

CREATE TABLE portal.funcionario_vinculo (
    cod_funcionario_vinculo integer DEFAULT nextval('portal.funcionario_vinculo_cod_funcionario_vinculo_seq'::regclass) NOT NULL,
    nm_vinculo character varying(255) DEFAULT ''::character varying NOT NULL,
    abreviatura character varying(16)
);


--
-- Name: cities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cities (
    id integer NOT NULL,
    state_id integer NOT NULL,
    name character varying(191) NOT NULL,
    ibge_code integer,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    deleted_at timestamp(0) without time zone
);


--
-- Name: cities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cities_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cities_id_seq OWNED BY public.cities.id;


--
-- Name: countries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.countries (
    id integer NOT NULL,
    name character varying(191) NOT NULL,
    ibge_code integer,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    deleted_at timestamp(0) without time zone
);


--
-- Name: countries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.countries_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: countries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.countries_id_seq OWNED BY public.countries.id;


--
-- Name: districts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.districts (
    id integer NOT NULL,
    city_id integer NOT NULL,
    name character varying(191) NOT NULL,
    ibge_code integer,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    deleted_at timestamp(0) without time zone
);


--
-- Name: districts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.districts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: districts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.districts_id_seq OWNED BY public.districts.id;


--
-- Name: educacenso_imports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.educacenso_imports (
    id bigint NOT NULL,
    year integer NOT NULL,
    school character varying(191) NOT NULL,
    user_id integer NOT NULL,
    finished boolean NOT NULL,
    error boolean DEFAULT false NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: educacenso_imports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.educacenso_imports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: educacenso_imports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.educacenso_imports_id_seq OWNED BY public.educacenso_imports.id;


--
-- Name: educacenso_record20; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.educacenso_record20 AS
 SELECT turma.cod_turma AS "codTurma",
    educacenso_cod_escola.cod_escola_inep AS "codigoEscolaInep",
    turma.ref_ref_cod_escola AS "codEscola",
    turma.ref_cod_curso AS "codCurso",
    turma.ref_ref_cod_serie AS "codSerie",
    turma.nm_turma AS "nomeTurma",
    turma.ano AS "anoTurma",
    turma.hora_inicial AS "horaInicial",
    turma.hora_final AS "horaFinal",
    turma.dias_semana AS "diasSemana",
    turma.tipo_atendimento AS "tipoAtendimento",
    turma.atividades_complementares AS "atividadesComplementares",
    turma.etapa_agregada AS "etapaAgregada",
    turma.etapa_educacenso AS "etapaEducacenso",
    juridica.fantasia AS "nomeEscola",
    turma.tipo_mediacao_didatico_pedagogico AS "tipoMediacaoDidaticoPedagogico",
    turma.organizacao_curricular AS "organizacaoCurricular",
    turma.formas_organizacao_turma AS "formasOrganizacaoTurma",
    turma.unidade_curricular AS "unidadesCurriculares",
    turma.classe_com_lingua_brasileira_sinais AS "classeComLinguaBrasileiraSinais",
    turma.classe_especial AS "classeEspecial",
    turma.outras_unidades_curriculares_obrigatorias AS "outrasUnidadesCurricularesObrigatorias",
    turma.turma_turno_id AS "turmaTurnoId",
    turma.hora_inicial_matutino AS "horaInicialMatutino",
    turma.hora_final_matutino AS "horaFinalMatutino",
    turma.hora_inicial_vespertino AS "horaInicialVespertino",
    turma.hora_final_vespertino AS "horaFinalVespertino",
    ( SELECT array_agg(t.unidade_curricular) AS unidades_curriculares
           FROM ( SELECT turma_1.cod_turma,
                    unnest(turma_1.unidade_curricular) AS unidade_curricular
                   FROM pmieducar.turma turma_1) t
          WHERE (true AND (NOT (EXISTS ( SELECT 1
                   FROM modules.professor_turma pt
                  WHERE (true AND (pt.turma_id = t.cod_turma) AND (ARRAY[t.unidade_curricular] <@ pt.unidades_curriculares))))) AND (t.cod_turma = turma.cod_turma))) AS "unidadesCurricularesSemDocenteVinculado",
    COALESCE(( SELECT 1
           FROM (modules.professor_turma
             JOIN pmieducar.servidor ON ((servidor.cod_servidor = professor_turma.servidor_id)))
          WHERE (professor_turma.turma_id = turma.cod_turma)
         LIMIT 1), 0) AS "possuiServidor",
    COALESCE(( SELECT 1
           FROM (modules.professor_turma
             JOIN pmieducar.servidor ON ((servidor.cod_servidor = professor_turma.servidor_id)))
          WHERE ((professor_turma.turma_id = turma.cod_turma) AND (professor_turma.funcao_exercida = ANY (ARRAY[1, 5])))
         LIMIT 1), 0) AS "possuiServidorDocente",
    COALESCE(( SELECT 1
           FROM (modules.professor_turma
             JOIN pmieducar.servidor ON ((servidor.cod_servidor = professor_turma.servidor_id)))
          WHERE ((professor_turma.turma_id = turma.cod_turma) AND (professor_turma.funcao_exercida = 4))
         LIMIT 1), 0) AS "possuiServidorLibras",
    COALESCE(( SELECT 1
           FROM (modules.professor_turma
             JOIN pmieducar.servidor ON ((servidor.cod_servidor = professor_turma.servidor_id)))
          WHERE ((professor_turma.turma_id = turma.cod_turma) AND (professor_turma.funcao_exercida = ANY (ARRAY[4, 6])))
         LIMIT 1), 0) AS "possuiServidorLibrasOuAuxiliarEad",
    COALESCE(( SELECT 1
           FROM (modules.professor_turma
             JOIN pmieducar.servidor ON ((servidor.cod_servidor = professor_turma.servidor_id)))
          WHERE ((professor_turma.turma_id = turma.cod_turma) AND (professor_turma.funcao_exercida <> ALL (ARRAY[4, 6])))
         LIMIT 1), 0) AS "possuiServidorDiferenteLibrasOuAuxiliarEad",
    COALESCE(( SELECT 1
           FROM ((((pmieducar.matricula_turma
             JOIN pmieducar.matricula ON ((matricula.cod_matricula = matricula_turma.ref_cod_matricula)))
             JOIN pmieducar.aluno ON ((aluno.cod_aluno = matricula.ref_cod_aluno)))
             JOIN cadastro.fisica_deficiencia ON ((fisica_deficiencia.ref_idpes = aluno.ref_idpes)))
             JOIN cadastro.deficiencia ON (((fisica_deficiencia.ref_cod_deficiencia = deficiencia.cod_deficiencia) AND (deficiencia.deficiencia_educacenso = ANY (ARRAY[3, 4, 5])))))
          WHERE ((matricula_turma.ref_cod_turma = turma.cod_turma) AND (matricula_turma.data_enturmacao <= instituicao.data_educacenso) AND (COALESCE(matricula_turma.data_exclusao, ('2999-01-01'::date)::timestamp without time zone) > instituicao.data_educacenso))
         LIMIT 1), 0) AS "possuiAlunoNecessitandoTradutor",
    COALESCE(( SELECT 1
           FROM (((modules.professor_turma
             JOIN pmieducar.servidor ON ((servidor.cod_servidor = professor_turma.servidor_id)))
             JOIN cadastro.fisica_deficiencia ON ((fisica_deficiencia.ref_idpes = servidor.cod_servidor)))
             JOIN cadastro.deficiencia ON (((fisica_deficiencia.ref_cod_deficiencia = deficiencia.cod_deficiencia) AND (deficiencia.deficiencia_educacenso = ANY (ARRAY[3, 4, 5])))))
          WHERE (professor_turma.turma_id = turma.cod_turma)
         LIMIT 1), 0) AS "possuiServidorNecessitandoTradutor",
    ( SELECT array_agg(DISTINCT cc.codigo_educacenso) AS array_agg
           FROM (((((pmieducar.turma t
             JOIN pmieducar.instituicao i ON ((i.cod_instituicao = t.ref_cod_instituicao)))
             JOIN modules.professor_turma pt ON ((pt.turma_id = t.cod_turma)))
             JOIN modules.professor_turma_disciplina ptd ON ((ptd.professor_turma_id = pt.id)))
             JOIN modules.componente_curricular cc ON ((cc.id = ptd.componente_curricular_id)))
             LEFT JOIN pmieducar.servidor_alocacao sa ON ((true AND (sa.ref_cod_servidor = pt.servidor_id) AND (sa.ref_cod_escola = t.ref_ref_cod_escola) AND (sa.ano = t.ano))))
          WHERE ((t.cod_turma = turma.cod_turma) AND (pt.funcao_exercida = ANY (ARRAY[1, 5])) AND (COALESCE(sa.data_admissao, '1900-01-01'::date) <= i.data_educacenso) AND (COALESCE(sa.data_saida, '2999-01-01'::date) >= i.data_educacenso))) AS "disciplinasEducacensoComDocentes",
    turma.local_funcionamento_diferenciado AS "localFuncionamentoDiferenciado",
    escola.local_funcionamento AS "localFuncionamento",
    curso.modalidade_curso AS "modalidadeCurso",
    turma.cod_curso_profissional AS "codCursoProfissional",
    turma.formacao_alternancia AS "formacaoAlternancia",
    turma.area_itinerario AS "areaItinerario",
    turma.tipo_curso_intinerario AS "tipoCursoIntinerario",
    turma.cod_curso_profissional_intinerario AS "codCursoProfissionalIntinerario"
   FROM (((((pmieducar.escola
     LEFT JOIN modules.educacenso_cod_escola ON ((escola.cod_escola = educacenso_cod_escola.cod_escola)))
     JOIN cadastro.juridica ON ((juridica.idpes = (escola.ref_idpes)::numeric)))
     JOIN pmieducar.turma ON ((turma.ref_ref_cod_escola = escola.cod_escola)))
     JOIN pmieducar.curso ON ((turma.ref_cod_curso = curso.cod_curso)))
     JOIN pmieducar.instituicao ON ((escola.ref_cod_instituicao = instituicao.cod_instituicao)))
  WHERE (true AND (COALESCE((turma.nao_informar_educacenso)::integer, 0) = 0) AND (turma.ativo = 1) AND (turma.visivel = true) AND (escola.ativo = 1) AND ((EXISTS ( SELECT 1
           FROM (pmieducar.matricula_turma
             JOIN pmieducar.matricula ON ((matricula.cod_matricula = matricula_turma.ref_cod_matricula)))
          WHERE ((matricula_turma.ref_cod_turma = turma.cod_turma) AND (matricula.ativo = 1) AND (matricula_turma.data_enturmacao < instituicao.data_educacenso) AND (COALESCE(matricula_turma.data_exclusao, ('2999-01-01'::date)::timestamp without time zone) >= instituicao.data_educacenso)))) OR (EXISTS ( SELECT 1
           FROM (pmieducar.matricula_turma
             JOIN pmieducar.matricula ON ((matricula.cod_matricula = matricula_turma.ref_cod_matricula)))
          WHERE ((matricula_turma.ref_cod_turma = turma.cod_turma) AND (matricula.ativo = 1) AND (matricula_turma.data_enturmacao = instituicao.data_educacenso) AND (COALESCE(matricula_turma.data_exclusao, ('2999-01-01'::date)::timestamp without time zone) >= instituicao.data_educacenso) AND (NOT (EXISTS ( SELECT 1
                   FROM (pmieducar.matricula_turma smt
                     JOIN pmieducar.matricula sm ON ((sm.cod_matricula = smt.ref_cod_matricula)))
                  WHERE ((sm.ref_cod_aluno = matricula.ref_cod_aluno) AND (sm.ativo = 1) AND (sm.ano = matricula.ano) AND (smt.data_enturmacao < matricula_turma.data_enturmacao) AND (COALESCE(smt.data_exclusao, ('2999-01-01'::date)::timestamp without time zone) >= instituicao.data_educacenso))))))))));


--
-- Name: educacenso_record50; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.educacenso_record50 AS
 SELECT DISTINCT '50'::text AS registro,
    educacenso_cod_escola.cod_escola_inep AS "inepEscola",
    servidor.cod_servidor AS "codigoPessoa",
    educacenso_cod_docente.cod_docente_inep AS "inepDocente",
    turma.cod_turma AS "codigoTurma",
    NULL::text AS "inepTurma",
    professor_turma.funcao_exercida AS "funcaoDocente",
    professor_turma.tipo_vinculo AS "tipoVinculo",
    tbl_componentes.componentes,
    professor_turma.unidades_curriculares AS "unidadesCurriculares",
    relatorio.get_nome_escola(escola.cod_escola) AS "nomeEscola",
    pessoa.nome AS "nomeDocente",
    servidor.cod_servidor AS "idServidor",
    instituicao.cod_instituicao AS "idInstituicao",
    professor_turma.id AS "idAlocacao",
    turma.tipo_mediacao_didatico_pedagogico AS "tipoMediacaoTurma",
    turma.tipo_atendimento AS "tipoAtendimentoTurma",
    turma.nm_turma AS "nomeTurma",
    escola.dependencia_administrativa AS "dependenciaAdministrativaEscola",
    turma.etapa_educacenso AS "etapaEducacensoTurma",
    turma.ano AS "anoTurma",
    escola.cod_escola AS "codEscola",
    turma.organizacao_curricular AS "organizacaoCurricular",
    professor_turma.outras_unidades_curriculares_obrigatorias AS "outrasUnidadesCurricularesObrigatorias",
    turma.turma_turno_id AS "turmaTurnoId",
    professor_turma.area_itinerario AS "areaItinerario",
    professor_turma.leciona_itinerario_tecnico_profissional AS "lecionaItinerarioTecnicoProfissional"
   FROM ((((((((((pmieducar.servidor
     JOIN modules.professor_turma ON ((professor_turma.servidor_id = servidor.cod_servidor)))
     JOIN pmieducar.turma ON (((turma.cod_turma = professor_turma.turma_id) AND (turma.ano = professor_turma.ano))))
     JOIN pmieducar.escola ON ((escola.cod_escola = turma.ref_ref_cod_escola)))
     JOIN pmieducar.instituicao ON ((escola.ref_cod_instituicao = instituicao.cod_instituicao)))
     JOIN cadastro.pessoa ON ((pessoa.idpes = (servidor.cod_servidor)::numeric)))
     LEFT JOIN pmieducar.servidor_alocacao ON (((servidor_alocacao.ref_cod_escola = escola.cod_escola) AND (servidor_alocacao.ref_cod_servidor = servidor.cod_servidor) AND (servidor_alocacao.ano = turma.ano))))
     LEFT JOIN modules.educacenso_cod_escola ON ((educacenso_cod_escola.cod_escola = escola.cod_escola)))
     LEFT JOIN modules.educacenso_cod_docente ON ((educacenso_cod_docente.cod_servidor = servidor.cod_servidor)))
     LEFT JOIN modules.educacenso_cod_turma ON ((educacenso_cod_turma.cod_turma = turma.cod_turma)))
     LEFT JOIN modules.professor_turma_disciplina ON ((professor_turma_disciplina.professor_turma_id = professor_turma.id))),
    LATERAL ( SELECT DISTINCT array_agg(DISTINCT cc.codigo_educacenso) AS componentes
           FROM (modules.componente_curricular cc
             JOIN modules.professor_turma_disciplina ptd ON ((cc.id = ptd.componente_curricular_id)))
          WHERE (ptd.professor_turma_id = professor_turma.id)) tbl_componentes
  WHERE (true AND (turma.ativo = 1) AND (turma.visivel = true) AND (escola.ativo = 1) AND (COALESCE((turma.nao_informar_educacenso)::integer, 0) = 0) AND (servidor.ativo = 1) AND (COALESCE(servidor_alocacao.data_admissao, '1900-01-01'::date) <= instituicao.data_educacenso) AND (COALESCE(servidor_alocacao.data_saida, '2999-01-01'::date) >= instituicao.data_educacenso) AND (COALESCE(professor_turma.data_inicial, '1900-01-01'::date) <= instituicao.data_educacenso) AND (COALESCE(professor_turma.data_fim, '2999-01-01'::date) >= instituicao.data_educacenso) AND ((EXISTS ( SELECT 1
           FROM (pmieducar.matricula_turma
             JOIN pmieducar.matricula ON ((matricula.cod_matricula = matricula_turma.ref_cod_matricula)))
          WHERE ((matricula_turma.ref_cod_turma = turma.cod_turma) AND (matricula.ativo = 1) AND (matricula_turma.data_enturmacao < instituicao.data_educacenso) AND (COALESCE(matricula_turma.data_exclusao, ('2999-01-01'::date)::timestamp without time zone) >= instituicao.data_educacenso)))) OR (EXISTS ( SELECT 1
           FROM (pmieducar.matricula_turma
             JOIN pmieducar.matricula ON ((matricula.cod_matricula = matricula_turma.ref_cod_matricula)))
          WHERE ((matricula_turma.ref_cod_turma = turma.cod_turma) AND (matricula.ativo = 1) AND (matricula_turma.data_enturmacao = instituicao.data_educacenso) AND (COALESCE(matricula_turma.data_exclusao, ('2999-01-01'::date)::timestamp without time zone) >= instituicao.data_educacenso) AND (NOT (EXISTS ( SELECT 1
                   FROM (pmieducar.matricula_turma smt
                     JOIN pmieducar.matricula sm ON ((sm.cod_matricula = smt.ref_cod_matricula)))
                  WHERE ((sm.ref_cod_aluno = matricula.ref_cod_aluno) AND (sm.ativo = 1) AND (sm.ano = matricula.ano) AND (smt.data_enturmacao < matricula_turma.data_enturmacao) AND (COALESCE(smt.data_exclusao, ('2999-01-01'::date)::timestamp without time zone) >= instituicao.data_educacenso))))))))));


--
-- Name: educacenso_record60; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.educacenso_record60 AS
 SELECT '60'::text AS registro,
    educacenso_cod_escola.cod_escola_inep AS "inepEscola",
    aluno.ref_idpes AS "codigoPessoa",
    educacenso_cod_aluno.cod_aluno_inep AS "inepAluno",
    turma.cod_turma AS "codigoTurma",
    NULL::text AS "inepTurma",
    NULL::text AS "matriculaAluno",
    matricula_turma.etapa_educacenso AS "etapaAluno",
    COALESCE(((ARRAY[1] <@ matricula_turma.tipo_atendimento))::integer, 0) AS "tipoAtendimentoDesenvolvimentoFuncoesGognitivas",
    COALESCE(((ARRAY[2] <@ matricula_turma.tipo_atendimento))::integer, 0) AS "tipoAtendimentoDesenvolvimentoVidaAutonoma",
    COALESCE(((ARRAY[3] <@ matricula_turma.tipo_atendimento))::integer, 0) AS "tipoAtendimentoEnriquecimentoCurricular",
    COALESCE(((ARRAY[4] <@ matricula_turma.tipo_atendimento))::integer, 0) AS "tipoAtendimentoEnsinoInformaticaAcessivel",
    COALESCE(((ARRAY[5] <@ matricula_turma.tipo_atendimento))::integer, 0) AS "tipoAtendimentoEnsinoLibras",
    COALESCE(((ARRAY[6] <@ matricula_turma.tipo_atendimento))::integer, 0) AS "tipoAtendimentoEnsinoLinguaPortuguesa",
    COALESCE(((ARRAY[7] <@ matricula_turma.tipo_atendimento))::integer, 0) AS "tipoAtendimentoEnsinoSoroban",
    COALESCE(((ARRAY[8] <@ matricula_turma.tipo_atendimento))::integer, 0) AS "tipoAtendimentoEnsinoBraile",
    COALESCE(((ARRAY[9] <@ matricula_turma.tipo_atendimento))::integer, 0) AS "tipoAtendimentoEnsinoOrientacaoMobilidade",
    COALESCE(((ARRAY[10] <@ matricula_turma.tipo_atendimento))::integer, 0) AS "tipoAtendimentoEnsinoCaa",
    COALESCE(((ARRAY[11] <@ matricula_turma.tipo_atendimento))::integer, 0) AS "tipoAtendimentoEnsinoRecursosOpticosNaoOpticos",
    aluno.recebe_escolarizacao_em_outro_espaco AS "recebeEscolarizacaoOutroEspacao",
        CASE
            WHEN (aluno.tipo_transporte > 0) THEN 1
            ELSE aluno.tipo_transporte
        END AS "transportePublico",
    aluno.tipo_transporte AS "poderPublicoResponsavelTransporte",
    ((ARRAY[4] <@ aluno.veiculo_transporte_escolar))::integer AS "veiculoTransporteBicicleta",
    ((ARRAY[2] <@ aluno.veiculo_transporte_escolar))::integer AS "veiculoTransporteMicroonibus",
    ((ARRAY[3] <@ aluno.veiculo_transporte_escolar))::integer AS "veiculoTransporteOnibus",
    ((ARRAY[5] <@ aluno.veiculo_transporte_escolar))::integer AS "veiculoTransporteTracaoAnimal",
    ((ARRAY[1] <@ aluno.veiculo_transporte_escolar))::integer AS "veiculoTransporteVanKonbi",
    ((ARRAY[6] <@ aluno.veiculo_transporte_escolar))::integer AS "veiculoTransporteOutro",
    ((ARRAY[7] <@ aluno.veiculo_transporte_escolar))::integer AS "veiculoTransporteAquaviarioCapacidade5",
    ((ARRAY[8] <@ aluno.veiculo_transporte_escolar))::integer AS "veiculoTransporteAquaviarioCapacidade5a15",
    ((ARRAY[9] <@ aluno.veiculo_transporte_escolar))::integer AS "veiculoTransporteAquaviarioCapacidade15a35",
    ((ARRAY[10] <@ aluno.veiculo_transporte_escolar))::integer AS "veiculoTransporteAquaviarioCapacidadeAcima35",
    relatorio.get_nome_escola(escola.cod_escola) AS "nomeEscola",
    pessoa.nome AS "nomeAluno",
    aluno.cod_aluno AS "codigoAluno",
    turma.tipo_atendimento AS "tipoAtendimentoTurma",
    turma.etapa_educacenso AS "etapaTurma",
    turma.organizacao_curricular AS "organizacaoCurricularTurma",
    matricula.cod_matricula AS "codigoMatricula",
    turma.nm_turma AS "nomeTurma",
    matricula_turma.tipo_atendimento AS "tipoAtendimentoMatricula",
    matricula_turma.id AS "enturmacaoId",
    turma.tipo_mediacao_didatico_pedagogico AS "tipoMediacaoTurma",
    aluno.veiculo_transporte_escolar AS "veiculoTransporteEscolar",
    curso.modalidade_curso AS "modalidadeCurso",
    turma.local_funcionamento_diferenciado AS "localFuncionamentoDiferenciadoTurma",
    fisica.pais_residencia AS "paisResidenciaAluno",
    matricula.ano AS "anoTurma",
    escola.cod_escola AS "codEscola",
    turma.turma_turno_id AS "turmaTurnoId",
    COALESCE(matricula_turma.turno_id, turma.turma_turno_id) AS "turnoId",
    turma.classe_especial AS "turmaClasseEspecial"
   FROM (((((((((((pmieducar.aluno
     JOIN pmieducar.matricula ON ((matricula.ref_cod_aluno = aluno.cod_aluno)))
     JOIN pmieducar.escola ON ((escola.cod_escola = matricula.ref_ref_cod_escola)))
     JOIN pmieducar.matricula_turma ON ((matricula_turma.ref_cod_matricula = matricula.cod_matricula)))
     JOIN pmieducar.instituicao ON ((instituicao.cod_instituicao = escola.ref_cod_instituicao)))
     JOIN pmieducar.turma ON ((turma.cod_turma = matricula_turma.ref_cod_turma)))
     JOIN pmieducar.curso ON ((curso.cod_curso = turma.ref_cod_curso)))
     JOIN cadastro.pessoa ON ((pessoa.idpes = (aluno.ref_idpes)::numeric)))
     JOIN cadastro.fisica ON ((fisica.idpes = pessoa.idpes)))
     LEFT JOIN modules.educacenso_cod_escola ON ((educacenso_cod_escola.cod_escola = escola.cod_escola)))
     LEFT JOIN modules.educacenso_cod_turma ON ((educacenso_cod_turma.cod_turma = turma.cod_turma)))
     LEFT JOIN modules.educacenso_cod_aluno ON ((educacenso_cod_aluno.cod_aluno = aluno.cod_aluno)))
  WHERE (true AND (matricula.ativo = 1) AND (turma.ativo = 1) AND (COALESCE((turma.nao_informar_educacenso)::integer, 0) = 0) AND (((matricula_turma.data_enturmacao < instituicao.data_educacenso) AND (COALESCE(matricula_turma.data_exclusao, ('2999-01-01'::date)::timestamp without time zone) >= instituicao.data_educacenso)) OR ((matricula_turma.data_enturmacao = instituicao.data_educacenso) AND (NOT (EXISTS ( SELECT 1
           FROM (pmieducar.matricula_turma smt
             JOIN pmieducar.matricula sm ON ((sm.cod_matricula = smt.ref_cod_matricula)))
          WHERE ((sm.ref_cod_aluno = matricula.ref_cod_aluno) AND (sm.ativo = 1) AND (sm.ano = matricula.ano) AND (smt.data_enturmacao < matricula_turma.data_enturmacao) AND (COALESCE(smt.data_exclusao, ('2999-01-01'::date)::timestamp without time zone) >= instituicao.data_educacenso))))))));


--
-- Name: employee_graduation_disciplines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.employee_graduation_disciplines (
    id integer NOT NULL,
    name character varying(191) NOT NULL
);


--
-- Name: employee_graduation_disciplines_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.employee_graduation_disciplines_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: employee_graduation_disciplines_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.employee_graduation_disciplines_id_seq OWNED BY public.employee_graduation_disciplines.id;


--
-- Name: employee_graduations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.employee_graduations (
    id integer NOT NULL,
    employee_id integer NOT NULL,
    course_id integer NOT NULL,
    completion_year integer NOT NULL,
    college_id integer NOT NULL,
    discipline_id integer,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: employee_graduations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.employee_graduations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: employee_graduations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.employee_graduations_id_seq OWNED BY public.employee_graduations.id;


--
-- Name: exporter_benefits; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exporter_benefits AS
 SELECT aab.aluno_id AS student_id,
    string_agg((ab.nm_beneficio)::text, ', '::text) AS benefits
   FROM (pmieducar.aluno_aluno_beneficio aab
     JOIN pmieducar.aluno_beneficio ab ON ((ab.cod_aluno_beneficio = aab.aluno_beneficio_id)))
  GROUP BY aab.aluno_id
  ORDER BY aab.aluno_id;


--
-- Name: exporter_disabilities; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exporter_disabilities AS
 SELECT fd.ref_idpes AS person_id,
    string_agg((d.nm_deficiencia)::text, ', '::text) AS disabilities
   FROM (cadastro.deficiencia d
     JOIN cadastro.fisica_deficiencia fd ON ((fd.ref_cod_deficiencia = d.cod_deficiencia)))
  GROUP BY fd.ref_idpes
  ORDER BY fd.ref_idpes;


--
-- Name: exporter_phones; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exporter_phones AS
 SELECT p.idpes AS person_id,
    string_agg(concat('(', fp.ddd, ') ', fp.fone), ', '::text) AS phones
   FROM (cadastro.pessoa p
     JOIN cadastro.fone_pessoa fp ON ((fp.idpes = p.idpes)))
  WHERE ((NULLIF(fp.fone, (0)::numeric) IS NOT NULL) AND (NULLIF(fp.ddd, (0)::numeric) IS NOT NULL))
  GROUP BY p.idpes
  ORDER BY p.idpes;


--
-- Name: exporter_projects; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exporter_projects AS
 SELECT pa.ref_cod_aluno AS student_id,
    string_agg((p.nome)::text, ', '::text) AS projects
   FROM (pmieducar.projeto_aluno pa
     JOIN pmieducar.projeto p ON ((p.cod_projeto = pa.ref_cod_projeto)))
  WHERE (pa.data_desligamento IS NULL)
  GROUP BY pa.ref_cod_aluno
  ORDER BY pa.ref_cod_aluno;


--
-- Name: exporter_school_class_stages; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exporter_school_class_stages AS
 SELECT DISTINCT turma.ano AS year,
    turma.ref_ref_cod_escola AS school_id,
    relatorio.get_nome_escola(turma.ref_ref_cod_escola) AS school_name,
    turma.nm_turma AS school_class,
    modulo.nm_tipo AS stage_name,
    ((turma_modulo.sequencial || 'º '::text) || (modulo.nm_tipo)::text) AS stage_number,
    turma_modulo.data_inicio AS stage_start_date,
    turma_modulo.data_fim AS stage_end_date,
    turma_modulo.dias_letivos AS stage_days,
    'Turma'::text AS stage_type,
    ( SELECT true
           FROM (((modules.nota_componente_curricular
             JOIN modules.nota_aluno ON ((nota_aluno.id = nota_componente_curricular.nota_aluno_id)))
             JOIN pmieducar.matricula ON ((matricula.cod_matricula = nota_aluno.matricula_id)))
             JOIN pmieducar.matricula_turma ON ((matricula_turma.ref_cod_matricula = matricula.cod_matricula)))
          WHERE ((matricula_turma.ref_cod_turma = turma.cod_turma) AND (matricula.ano = turma.ano) AND (matricula.ativo = 1) AND (matricula_turma.ativo = 1) AND ((nota_componente_curricular.etapa)::text = ((turma_modulo.sequencial)::character varying)::text))
         LIMIT 1) AS posted_scores,
    ( SELECT true
           FROM (((modules.falta_componente_curricular
             JOIN modules.falta_aluno ON ((falta_aluno.id = falta_componente_curricular.falta_aluno_id)))
             JOIN pmieducar.matricula ON ((matricula.cod_matricula = falta_aluno.matricula_id)))
             JOIN pmieducar.matricula_turma ON ((matricula_turma.ref_cod_matricula = matricula.cod_matricula)))
          WHERE ((matricula_turma.ref_cod_turma = turma.cod_turma) AND (matricula.ano = turma.ano) AND (matricula.ativo = 1) AND (matricula_turma.ativo = 1) AND ((falta_componente_curricular.etapa)::text = ((turma_modulo.sequencial)::character varying)::text))
         LIMIT 1) AS posted_absences,
    ( SELECT true
           FROM (((modules.parecer_componente_curricular
             JOIN modules.parecer_aluno ON ((parecer_aluno.id = parecer_componente_curricular.parecer_aluno_id)))
             JOIN pmieducar.matricula ON ((matricula.cod_matricula = parecer_aluno.matricula_id)))
             JOIN pmieducar.matricula_turma ON ((matricula_turma.ref_cod_matricula = matricula.cod_matricula)))
          WHERE ((matricula_turma.ref_cod_turma = turma.cod_turma) AND (matricula.ano = turma.ano) AND (matricula.ativo = 1) AND (matricula_turma.ativo = 1) AND ((parecer_componente_curricular.etapa)::text = ((turma_modulo.sequencial)::character varying)::text))
         LIMIT 1) AS posted_descritive_opinions,
    ( SELECT true
           FROM (((modules.falta_geral
             JOIN modules.falta_aluno ON ((falta_aluno.id = falta_geral.falta_aluno_id)))
             JOIN pmieducar.matricula ON ((matricula.cod_matricula = falta_aluno.matricula_id)))
             JOIN pmieducar.matricula_turma ON ((matricula_turma.ref_cod_matricula = matricula.cod_matricula)))
          WHERE ((matricula_turma.ref_cod_turma = turma.cod_turma) AND (matricula.ano = turma.ano) AND (matricula.ativo = 1) AND (matricula_turma.ativo = 1) AND ((falta_geral.etapa)::text = ((turma_modulo.sequencial)::character varying)::text))
         LIMIT 1) AS posted_general_absence,
    ( SELECT true
           FROM (((modules.nota_geral
             JOIN modules.nota_aluno ON ((nota_aluno.id = nota_geral.nota_aluno_id)))
             JOIN pmieducar.matricula ON ((matricula.cod_matricula = nota_aluno.matricula_id)))
             JOIN pmieducar.matricula_turma ON ((matricula_turma.ref_cod_matricula = matricula.cod_matricula)))
          WHERE ((matricula_turma.ref_cod_turma = turma.cod_turma) AND (matricula.ano = turma.ano) AND (matricula.ativo = 1) AND (matricula_turma.ativo = 1) AND ((nota_geral.etapa)::text = ((turma_modulo.sequencial)::character varying)::text))
         LIMIT 1) AS posted_general_score,
    ( SELECT true
           FROM (((modules.parecer_geral
             JOIN modules.parecer_aluno ON ((parecer_aluno.id = parecer_geral.parecer_aluno_id)))
             JOIN pmieducar.matricula ON ((matricula.cod_matricula = parecer_aluno.matricula_id)))
             JOIN pmieducar.matricula_turma ON ((matricula_turma.ref_cod_matricula = matricula.cod_matricula)))
          WHERE ((matricula_turma.ref_cod_turma = turma.cod_turma) AND (matricula.ano = turma.ano) AND (matricula.ativo = 1) AND (matricula_turma.ativo = 1) AND ((parecer_geral.etapa)::text = ((turma_modulo.sequencial)::character varying)::text))
         LIMIT 1) AS posted_general_descritive_opinions
   FROM (((pmieducar.turma_modulo
     JOIN pmieducar.turma ON ((turma.cod_turma = turma_modulo.ref_cod_turma)))
     JOIN pmieducar.modulo ON ((modulo.cod_modulo = turma_modulo.ref_cod_modulo)))
     JOIN pmieducar.curso ON ((curso.cod_curso = turma.ref_cod_curso)))
  WHERE (true AND (turma.ativo = 1) AND (curso.padrao_ano_escolar = 0));


--
-- Name: exporter_school_stages; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exporter_school_stages AS
 SELECT DISTINCT ano_letivo_modulo.ref_ano AS year,
    escola.cod_escola AS school_id,
    relatorio.get_nome_escola(escola.cod_escola) AS school_name,
    '-'::text AS school_class,
    modulo.nm_tipo AS stage_name,
    ((ano_letivo_modulo.sequencial || 'º '::text) || (modulo.nm_tipo)::text) AS stage_number,
    ano_letivo_modulo.data_inicio AS stage_start_date,
    ano_letivo_modulo.data_fim AS stage_end_date,
    ano_letivo_modulo.dias_letivos AS stage_days,
    'Padrão'::text AS stage_type,
    ( SELECT true
           FROM ((modules.nota_componente_curricular
             JOIN modules.nota_aluno ON ((nota_aluno.id = nota_componente_curricular.nota_aluno_id)))
             JOIN pmieducar.matricula ON ((matricula.cod_matricula = nota_aluno.matricula_id)))
          WHERE ((matricula.ref_ref_cod_escola = escola.cod_escola) AND (matricula.ano = ano_letivo_modulo.ref_ano) AND (matricula.ativo = 1) AND ((nota_componente_curricular.etapa)::text = ((ano_letivo_modulo.sequencial)::character varying)::text))
         LIMIT 1) AS posted_scores,
    ( SELECT true
           FROM ((modules.falta_componente_curricular
             JOIN modules.falta_aluno ON ((falta_aluno.id = falta_componente_curricular.falta_aluno_id)))
             JOIN pmieducar.matricula ON ((matricula.cod_matricula = falta_aluno.matricula_id)))
          WHERE ((matricula.ref_ref_cod_escola = escola.cod_escola) AND (matricula.ano = ano_letivo_modulo.ref_ano) AND (matricula.ativo = 1) AND ((falta_componente_curricular.etapa)::text = ((ano_letivo_modulo.sequencial)::character varying)::text))
         LIMIT 1) AS posted_absences,
    ( SELECT true
           FROM ((modules.parecer_componente_curricular
             JOIN modules.parecer_aluno ON ((parecer_aluno.id = parecer_componente_curricular.parecer_aluno_id)))
             JOIN pmieducar.matricula ON ((matricula.cod_matricula = parecer_aluno.matricula_id)))
          WHERE ((matricula.ref_ref_cod_escola = escola.cod_escola) AND (matricula.ano = ano_letivo_modulo.ref_ano) AND (matricula.ativo = 1) AND ((parecer_componente_curricular.etapa)::text = ((ano_letivo_modulo.sequencial)::character varying)::text))
         LIMIT 1) AS posted_descritive_opinions,
    ( SELECT true
           FROM ((modules.falta_geral
             JOIN modules.falta_aluno ON ((falta_aluno.id = falta_geral.falta_aluno_id)))
             JOIN pmieducar.matricula ON ((matricula.cod_matricula = falta_aluno.matricula_id)))
          WHERE ((matricula.ref_ref_cod_escola = escola.cod_escola) AND (matricula.ano = ano_letivo_modulo.ref_ano) AND (matricula.ativo = 1) AND ((falta_geral.etapa)::text = ((ano_letivo_modulo.sequencial)::character varying)::text))
         LIMIT 1) AS posted_general_absence,
    ( SELECT true
           FROM ((modules.nota_geral
             JOIN modules.nota_aluno ON ((nota_aluno.id = nota_geral.nota_aluno_id)))
             JOIN pmieducar.matricula ON ((matricula.cod_matricula = nota_aluno.matricula_id)))
          WHERE ((matricula.ref_ref_cod_escola = escola.cod_escola) AND (matricula.ano = ano_letivo_modulo.ref_ano) AND (matricula.ativo = 1) AND ((nota_geral.etapa)::text = ((ano_letivo_modulo.sequencial)::character varying)::text))
         LIMIT 1) AS posted_general_score,
    ( SELECT true
           FROM ((modules.parecer_geral
             JOIN modules.parecer_aluno ON ((parecer_aluno.id = parecer_geral.parecer_aluno_id)))
             JOIN pmieducar.matricula ON ((matricula.cod_matricula = parecer_aluno.matricula_id)))
          WHERE ((matricula.ref_ref_cod_escola = escola.cod_escola) AND (matricula.ano = ano_letivo_modulo.ref_ano) AND (matricula.ativo = 1) AND ((parecer_geral.etapa)::text = ((ano_letivo_modulo.sequencial)::character varying)::text))
         LIMIT 1) AS posted_general_descritive_opinions
   FROM ((pmieducar.ano_letivo_modulo
     JOIN pmieducar.escola ON ((escola.cod_escola = ano_letivo_modulo.ref_ref_cod_escola)))
     JOIN pmieducar.modulo ON ((modulo.cod_modulo = ano_letivo_modulo.ref_cod_modulo)))
  WHERE (true AND (escola.ativo = 1));


--
-- Name: exporter_stages; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exporter_stages AS
 SELECT exporter_school_stages.year,
    exporter_school_stages.school_id,
    exporter_school_stages.school_name,
    exporter_school_stages.school_class,
    exporter_school_stages.stage_name,
    exporter_school_stages.stage_number,
    exporter_school_stages.stage_start_date,
    exporter_school_stages.stage_end_date,
    exporter_school_stages.stage_days,
    exporter_school_stages.stage_type,
    exporter_school_stages.posted_scores,
    exporter_school_stages.posted_absences,
    exporter_school_stages.posted_descritive_opinions,
    exporter_school_stages.posted_general_absence,
    exporter_school_stages.posted_general_score,
    exporter_school_stages.posted_general_descritive_opinions,
        CASE
            WHEN (exporter_school_stages.posted_scores OR exporter_school_stages.posted_absences OR exporter_school_stages.posted_descritive_opinions OR exporter_school_stages.posted_general_absence OR exporter_school_stages.posted_general_score OR exporter_school_stages.posted_general_descritive_opinions) THEN 'Sim'::text
            ELSE NULL::text
        END AS posted_data
   FROM public.exporter_school_stages
UNION
 SELECT exporter_school_class_stages.year,
    exporter_school_class_stages.school_id,
    exporter_school_class_stages.school_name,
    exporter_school_class_stages.school_class,
    exporter_school_class_stages.stage_name,
    exporter_school_class_stages.stage_number,
    exporter_school_class_stages.stage_start_date,
    exporter_school_class_stages.stage_end_date,
    exporter_school_class_stages.stage_days,
    exporter_school_class_stages.stage_type,
    exporter_school_class_stages.posted_scores,
    exporter_school_class_stages.posted_absences,
    exporter_school_class_stages.posted_descritive_opinions,
    exporter_school_class_stages.posted_general_absence,
    exporter_school_class_stages.posted_general_score,
    exporter_school_class_stages.posted_general_descritive_opinions,
        CASE
            WHEN (exporter_school_class_stages.posted_scores OR exporter_school_class_stages.posted_absences OR exporter_school_class_stages.posted_descritive_opinions OR exporter_school_class_stages.posted_general_absence OR exporter_school_class_stages.posted_general_score OR exporter_school_class_stages.posted_general_descritive_opinions) THEN 'Sim'::text
            ELSE NULL::text
        END AS posted_data
   FROM public.exporter_school_class_stages;


--
-- Name: exporter_teacher_disciplines; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.exporter_teacher_disciplines AS
 SELECT ptd.professor_turma_id AS pivot_id,
    string_agg((cc.nome)::text, ', '::text) AS disciplines
   FROM (modules.professor_turma_disciplina ptd
     JOIN modules.componente_curricular cc ON ((cc.id = ptd.componente_curricular_id)))
  GROUP BY ptd.professor_turma_id
  ORDER BY ptd.professor_turma_id;


--
-- Name: ieducar_audit; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ieducar_audit (
    id bigint NOT NULL,
    context json,
    before json,
    after json,
    schema character varying(191) NOT NULL,
    "table" character varying(191) NOT NULL,
    date timestamp(0) without time zone NOT NULL
);


--
-- Name: ieducar_audit_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ieducar_audit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ieducar_audit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ieducar_audit_id_seq OWNED BY public.ieducar_audit.id;


--
-- Name: individuals; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.individuals AS
 SELECT idpes AS id,
    idpes AS person_id,
    nome_social AS social_name,
    data_nasc AS birthdate,
        CASE sexo
            WHEN 'M'::bpchar THEN 1
            WHEN 'F'::bpchar THEN 2
            ELSE NULL::integer
        END AS gender,
    idpes_mae AS mother_individual_id,
    idpes_pai AS father_individual_id,
    idpes_responsavel AS guardian_individual_id,
    nacionalidade AS nationality,
    idpais_estrangeiro AS country_id,
    data_chegada_brasil AS arrived_at,
    idmun_nascimento AS city_id,
    nome_mae AS mother_name,
    nome_pai AS father_name,
    nome_conjuge AS spouse_name,
    nome_responsavel AS guardian_name,
    idpes_rev AS updated_by,
    (data_rev)::timestamp(0) without time zone AS updated_at,
        CASE origem_gravacao
            WHEN 'M'::bpchar THEN 1
            WHEN 'C'::bpchar THEN 2
            WHEN 'U'::bpchar THEN 3
            WHEN 'O'::bpchar THEN 4
            ELSE NULL::integer
        END AS registry_origin,
    idpes_cad AS created_by,
    (data_cad)::timestamp(0) without time zone AS created_at,
    cpf,
    ref_cod_religiao AS religion_id,
    nis_pis_pasep,
    sus,
    ocupacao AS ocupation,
    empresa AS company,
    pessoa_contato AS contact_name,
    renda_mensal AS monthly_income,
    data_admissao AS admitted_at,
    ddd_telefone_empresa AS company_area_code,
    telefone_empresa AS company_phone,
    falecido AS deceased,
    (
        CASE
            WHEN (ativo = 0) THEN data_exclusao
            ELSE NULL::timestamp without time zone
        END)::timestamp(0) without time zone AS deleted_at,
    ref_usuario_exc AS deleted_by,
    zona_localizacao_censo AS localization_zone,
    tipo_trabalho AS job_type,
    local_trabalho AS job_location,
    horario_inicial_trabalho AS job_start_time,
    horario_final_trabalho AS job_end_time
   FROM cadastro.fisica;


--
-- Name: info_enrollment; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.info_enrollment AS
 SELECT matricula.ref_ref_cod_escola AS school_id,
    matricula.ref_cod_curso AS course_id,
    matricula.ref_ref_cod_serie AS grade_id,
    COALESCE(enturmacao.turno_id, turma.turma_turno_id) AS period_id,
    turma.cod_turma AS classroom_id,
    turma.ref_ref_cod_escola AS classroom_school_id,
    turma.ref_cod_curso AS classroom_course_id,
    turma.ref_ref_cod_serie AS classroom_grade_id,
    turma.turma_turno_id AS classroom_period_id,
    matricula.ref_cod_aluno AS student_id,
    enturmacao.id AS enrollment_id,
    matricula.cod_matricula AS registration_id,
    enturmacao.sequencial AS sequential,
    ( SELECT max(matricula_turma.sequencial) AS max
           FROM pmieducar.matricula_turma
          WHERE (matricula_turma.ref_cod_matricula = matricula.cod_matricula)) AS last_sequential,
    (matricula.ativo = 1) AS registration_active,
    (matricula.aprovado = 4) AS registration_transferred,
    (matricula.aprovado = 5) AS registration_reclassified,
    (matricula.aprovado = 6) AS registration_abandoned,
    (matricula.aprovado = 15) AS registration_deceased,
    (matricula.aprovado = ANY (ARRAY[1, 2, 12, 13, 14])) AS registration_next,
    (matricula.aprovado = ANY (ARRAY[1, 12, 13])) AS registration_approved,
    (matricula.aprovado = ANY (ARRAY[2, 14])) AS registration_reproved,
    (matricula.matricula_reclassificacao = 1) AS registration_was_reclassified,
    (enturmacao.ativo = 1) AS enrollment_active,
    enturmacao.transferido AS enrollment_transferred,
    enturmacao.reclassificado AS enrollment_reclassified,
    enturmacao.abandono AS enrollment_abandoned,
    enturmacao.falecido AS enrollment_deceased,
    enturmacao.remanejado AS enrollment_relocated,
    ((matricula.aprovado = 5) AND enturmacao.reclassificado) AS reclassified,
    ((matricula.aprovado = 4) AND enturmacao.transferido) AS transferred,
    ((matricula.aprovado = 6) AND enturmacao.abandono) AS abandoned,
    ((matricula.aprovado = 15) AND enturmacao.falecido) AS deceased,
    enturmacao.remanejado AS relocated,
    (matricula.dependencia = true) AS dependence,
    (COALESCE((enturmacao.data_enturmacao)::timestamp without time zone, matricula.data_matricula, matricula.data_cadastro))::date AS start_date,
    (COALESCE(enturmacao.data_exclusao, matricula.data_cancel, matricula.data_exclusao))::date AS end_date
   FROM ((pmieducar.matricula_turma enturmacao
     JOIN pmieducar.matricula matricula ON ((true AND (matricula.cod_matricula = enturmacao.ref_cod_matricula))))
     JOIN pmieducar.turma turma ON ((true AND (turma.cod_turma = enturmacao.ref_cod_turma) AND (turma.ativo = 1))));


--
-- Name: log_unification_old_data; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.log_unification_old_data (
    id integer NOT NULL,
    unification_id integer NOT NULL,
    "table" character varying(191) NOT NULL,
    keys json NOT NULL,
    old_data json NOT NULL
);


--
-- Name: log_unification_old_data_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.log_unification_old_data_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: log_unification_old_data_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.log_unification_old_data_id_seq OWNED BY public.log_unification_old_data.id;


--
-- Name: log_unifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.log_unifications (
    id integer NOT NULL,
    type character varying(191) NOT NULL,
    main_id integer NOT NULL,
    duplicates_id json NOT NULL,
    created_by integer NOT NULL,
    updated_by integer NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: log_unifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.log_unifications_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: log_unifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.log_unifications_id_seq OWNED BY public.log_unifications.id;


--
-- Name: manager_access_criterias; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.manager_access_criterias (
    id integer NOT NULL,
    name character varying(191) NOT NULL
);


--
-- Name: manager_access_criterias_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.manager_access_criterias_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: manager_access_criterias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.manager_access_criterias_id_seq OWNED BY public.manager_access_criterias.id;


--
-- Name: manager_link_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.manager_link_types (
    id integer NOT NULL,
    name character varying(191) NOT NULL
);


--
-- Name: manager_link_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.manager_link_types_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: manager_link_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.manager_link_types_id_seq OWNED BY public.manager_link_types.id;


--
-- Name: manager_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.manager_roles (
    id integer NOT NULL,
    name character varying(191) NOT NULL
);


--
-- Name: manager_roles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.manager_roles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: manager_roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.manager_roles_id_seq OWNED BY public.manager_roles.id;


--
-- Name: menus; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.menus (
    id integer NOT NULL,
    parent_id integer,
    title character varying(191) NOT NULL,
    description character varying(191),
    link character varying(191),
    icon character varying(191),
    "order" integer DEFAULT 99 NOT NULL,
    type integer DEFAULT 1 NOT NULL,
    process integer,
    old integer,
    parent_old integer,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: menus_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.menus_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: menus_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.menus_id_seq OWNED BY public.menus.id;


--
-- Name: migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.migrations (
    id integer NOT NULL,
    migration character varying(191) NOT NULL,
    batch integer NOT NULL
);


--
-- Name: migrations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.migrations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: migrations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.migrations_id_seq OWNED BY public.migrations.id;


--
-- Name: password_resets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.password_resets (
    email character varying(191) NOT NULL,
    token character varying(191) NOT NULL,
    created_at timestamp(0) without time zone
);


--
-- Name: personal_access_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.personal_access_tokens (
    id bigint NOT NULL,
    tokenable_type character varying(191) NOT NULL,
    tokenable_id bigint NOT NULL,
    name character varying(191) NOT NULL,
    token character varying(64) NOT NULL,
    abilities text,
    last_used_at timestamp(0) without time zone,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: personal_access_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.personal_access_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: personal_access_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.personal_access_tokens_id_seq OWNED BY public.personal_access_tokens.id;


--
-- Name: persons; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.persons AS
 SELECT idpes AS id,
    nome AS name,
    idpes_cad AS created_by,
    (data_cad)::timestamp(0) without time zone AS created_at,
    url,
        CASE tipo
            WHEN 'F'::bpchar THEN 1
            WHEN 'J'::bpchar THEN 2
            ELSE NULL::integer
        END AS type,
    idpes_rev AS updated_by,
    data_rev AS updated_at,
    email,
        CASE origem_gravacao
            WHEN 'M'::bpchar THEN 1
            WHEN 'C'::bpchar THEN 2
            WHEN 'U'::bpchar THEN 3
            WHEN 'O'::bpchar THEN 4
            ELSE NULL::integer
        END AS registry_origin
   FROM cadastro.pessoa;


--
-- Name: phones; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.phones AS
 SELECT ((idpes || '-'::text) || tipo) AS id,
    idpes AS person_id,
    tipo AS type_id,
    ddd AS area_code,
    fone AS number,
    idpes_cad AS created_by,
    idpes_rev AS updated_by,
    (data_cad)::timestamp(0) without time zone AS created_at,
    (data_rev)::timestamp(0) without time zone AS updated_at
   FROM cadastro.fone_pessoa;


--
-- Name: registrations; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.registrations AS
 SELECT cod_matricula AS id,
    ref_cod_aluno AS student_id,
    ref_ref_cod_escola AS school_id,
    ref_cod_curso AS course_id,
    ref_ref_cod_serie AS level_id,
    ref_cod_abandono_tipo AS abandonment_id,
    turno_pre_matricula AS reservation_shift_id,
    aprovado AS status,
    ano AS year,
    semestre AS semester,
    observacao AS observations,
    descricao_reclassificacao AS reclassification_description,
    ultima_matricula AS is_last_registration,
    formando AS is_graduand,
    matricula_reclassificacao AS is_reclassified,
    matricula_transferencia AS is_transference,
    dependencia AS is_dependency,
    saida_escola AS has_left_school,
    ref_usuario_cad AS created_by,
    ref_usuario_exc AS deleted_by,
    data_matricula AS registrated_at,
    data_cancel AS canceled_at,
    data_saida_escola AS left_school_at,
    (data_cadastro)::timestamp(0) without time zone AS created_at,
    (updated_at)::timestamp(0) without time zone AS updated_at,
    (
        CASE
            WHEN (ativo = 0) THEN data_exclusao
            ELSE NULL::timestamp without time zone
        END)::timestamp(0) without time zone AS deleted_at
   FROM pmieducar.matricula;


--
-- Name: seq_setor_bai; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.seq_setor_bai
    START WITH 1
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


--
-- Name: students; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.students AS
 SELECT cod_aluno AS id,
    ref_cod_religiao AS religion_id,
    ref_usuario_exc AS deleted_by,
    ref_usuario_cad AS created_by,
    ref_idpes AS individual_id,
    (data_cadastro)::timestamp(0) without time zone AS created_at,
    (
        CASE
            WHEN (ativo = 0) THEN data_exclusao
            ELSE NULL::timestamp without time zone
        END)::timestamp(0) without time zone AS deleted_at,
    caminho_foto AS picture_path,
    analfabeto AS illiterate,
    nm_pai AS father_name,
    nm_mae AS mother_name,
        CASE tipo_responsavel
            WHEN 'p'::bpchar THEN 1
            WHEN 'm'::bpchar THEN 2
            WHEN 'a'::bpchar THEN 3
            WHEN 'r'::bpchar THEN 4
            ELSE NULL::integer
        END AS guardian_type,
    aluno_estado_id AS registry_code,
    justificativa_falta_documentacao AS missing_docs_rationale,
    url_laudo_medico AS medical_report_path,
    codigo_sistema AS system_code,
    tipo_transporte AS transportation_provider,
    veiculo_transporte_escolar AS transportation_vehicle_type,
    autorizado_um AS pickup_authorized_first,
    parentesco_um AS pickup_kinship_first,
    autorizado_dois AS pickup_authorized_second,
    parentesco_dois AS pickup_kinship_second,
    autorizado_tres AS pickup_authorized_third,
    parentesco_tres AS pickup_kinship_third,
    autorizado_quatro AS pickup_authorized_fourth,
    parentesco_quatro AS pickup_kinship_fourth,
    autorizado_cinco AS pickup_authorized_fifth,
    parentesco_cinco AS pickup_kinship_fifth,
    url_documento AS document_path,
    recebe_escolarizacao_em_outro_espaco AS schooling_in_other_space,
    recursos_prova_inep AS inep_test_resources
   FROM pmieducar.aluno a;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    name character varying(191) NOT NULL,
    email character varying(191) NOT NULL,
    email_verified_at timestamp(0) without time zone,
    password character varying(191) NOT NULL,
    remember_token character varying(100),
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: situacao_matricula; Type: TABLE; Schema: relatorio; Owner: -
--

CREATE TABLE relatorio.situacao_matricula (
    cod_situacao integer NOT NULL,
    descricao character varying(50) NOT NULL
);


--
-- Name: view_auditoria; Type: VIEW; Schema: relatorio; Owner: -
--

CREATE VIEW relatorio.view_auditoria AS
 SELECT (substr((usuario)::text, 0, strpos((usuario)::text, '-'::text)))::integer AS usuario_id,
    substr((usuario)::text, (strpos((usuario)::text, '-'::text) + 2)) AS usuario_matricula,
    operacao,
    rotina,
    data_hora,
        CASE
            WHEN (operacao = 1) THEN relatorio.get_valor_campo_auditoria('instituicao'::character varying, 'instituicao_id'::character varying, (valor_novo)::character varying)
            ELSE relatorio.get_valor_campo_auditoria('instituicao'::character varying, 'instituicao_id'::character varying, (valor_antigo)::character varying)
        END AS instituicao,
    (
        CASE
            WHEN (operacao = 1) THEN relatorio.get_valor_campo_auditoria('instituicao_id'::character varying, 'escola'::character varying, (valor_novo)::character varying)
            ELSE relatorio.get_valor_campo_auditoria('instituicao_id'::character varying, 'escola'::character varying, (valor_antigo)::character varying)
        END)::integer AS instituicao_id,
        CASE
            WHEN (operacao = 1) THEN relatorio.get_valor_campo_auditoria('escola'::character varying, 'escola_id'::character varying, (valor_novo)::character varying)
            ELSE relatorio.get_valor_campo_auditoria('escola'::character varying, 'escola_id'::character varying, (valor_antigo)::character varying)
        END AS escola,
    (
        CASE
            WHEN (operacao = 1) THEN relatorio.get_valor_campo_auditoria('escola_id'::character varying, 'curso'::character varying, (valor_novo)::character varying)
            ELSE relatorio.get_valor_campo_auditoria('escola_id'::character varying, 'curso'::character varying, (valor_antigo)::character varying)
        END)::integer AS escola_id,
        CASE
            WHEN (operacao = 1) THEN relatorio.get_valor_campo_auditoria('curso'::character varying, 'curso_id'::character varying, (valor_novo)::character varying)
            ELSE relatorio.get_valor_campo_auditoria('curso'::character varying, 'curso_id'::character varying, (valor_antigo)::character varying)
        END AS curso,
    (
        CASE
            WHEN (operacao = 1) THEN relatorio.get_valor_campo_auditoria('curso_id'::character varying, 'serie'::character varying, (valor_novo)::character varying)
            ELSE relatorio.get_valor_campo_auditoria('curso_id'::character varying, 'serie'::character varying, (valor_antigo)::character varying)
        END)::integer AS curso_id,
        CASE
            WHEN (operacao = 1) THEN relatorio.get_valor_campo_auditoria('serie'::character varying, 'serie_id'::character varying, (valor_novo)::character varying)
            ELSE relatorio.get_valor_campo_auditoria('serie'::character varying, 'serie_id'::character varying, (valor_antigo)::character varying)
        END AS serie,
    (
        CASE
            WHEN (operacao = 1) THEN relatorio.get_valor_campo_auditoria('serie_id'::character varying, 'turma'::character varying, (valor_novo)::character varying)
            ELSE relatorio.get_valor_campo_auditoria('serie_id'::character varying, 'turma'::character varying, (valor_antigo)::character varying)
        END)::integer AS serie_id,
        CASE
            WHEN (operacao = 1) THEN relatorio.get_valor_campo_auditoria('turma'::character varying, 'turma_id'::character varying, (valor_novo)::character varying)
            ELSE relatorio.get_valor_campo_auditoria('turma'::character varying, 'turma_id'::character varying, (valor_antigo)::character varying)
        END AS turma,
    (
        CASE
            WHEN (operacao = 1) THEN relatorio.get_valor_campo_auditoria('turma_id'::character varying, 'aluno'::character varying, (valor_novo)::character varying)
            ELSE relatorio.get_valor_campo_auditoria('turma_id'::character varying, 'aluno'::character varying, (valor_antigo)::character varying)
        END)::integer AS turma_id,
        CASE
            WHEN (operacao = 1) THEN relatorio.get_valor_campo_auditoria('aluno'::character varying, 'aluno_id'::character varying, (valor_novo)::character varying)
            ELSE relatorio.get_valor_campo_auditoria('aluno'::character varying, 'aluno_id'::character varying, (valor_antigo)::character varying)
        END AS aluno,
    (
        CASE
            WHEN (operacao = 1) THEN relatorio.get_valor_campo_auditoria('aluno_id'::character varying, 'nota'::character varying, (valor_novo)::character varying)
            ELSE relatorio.get_valor_campo_auditoria('aluno_id'::character varying, 'nota'::character varying, (valor_antigo)::character varying)
        END)::integer AS aluno_id,
        CASE
            WHEN (operacao = 1) THEN relatorio.get_valor_campo_auditoria('etapa'::character varying, 'componenteCurricular'::character varying, (valor_novo)::character varying)
            ELSE relatorio.get_valor_campo_auditoria('etapa'::character varying, 'componenteCurricular'::character varying, (valor_antigo)::character varying)
        END AS etapa,
        CASE
            WHEN (operacao = 1) THEN relatorio.get_valor_campo_auditoria('componenteCurricular'::character varying, ''::character varying, (valor_novo)::character varying)
            ELSE relatorio.get_valor_campo_auditoria('componenteCurricular'::character varying, ''::character varying, (valor_antigo)::character varying)
        END AS componente_curricular,
    relatorio.get_valor_campo_auditoria('nota'::character varying, 'etapa'::character varying, (valor_antigo)::character varying) AS nota_antiga,
    relatorio.get_valor_campo_auditoria('nota'::character varying, 'etapa'::character varying, (valor_novo)::character varying) AS nota_nova
   FROM modules.auditoria;


--
-- Name: view_componente_curricular; Type: VIEW; Schema: relatorio; Owner: -
--

CREATE VIEW relatorio.view_componente_curricular AS
 SELECT cc.id,
    t.cod_turma,
    COALESCE(ts.serie_id, t.ref_ref_cod_serie) AS cod_serie,
    cc.nome,
    cc.abreviatura,
    cc.ordenamento,
    cc.area_conhecimento_id,
    cc.tipo_base,
    esd.etapas_especificas,
    esd.etapas_utilizadas,
    COALESCE(cct.carga_horaria, esd.carga_horaria, ccae.carga_horaria) AS carga_horaria
   FROM ((((((pmieducar.turma t
     LEFT JOIN pmieducar.turma_serie ts ON ((ts.turma_id = t.cod_turma)))
     JOIN pmieducar.escola_serie es ON (((es.ref_cod_escola = t.ref_ref_cod_escola) AND (es.ref_cod_serie = COALESCE(ts.serie_id, t.ref_ref_cod_serie)))))
     JOIN pmieducar.escola_serie_disciplina esd ON (((esd.ref_ref_cod_escola = es.ref_cod_escola) AND (esd.ref_ref_cod_serie = es.ref_cod_serie))))
     JOIN modules.componente_curricular_ano_escolar ccae ON (((ccae.ano_escolar_id = es.ref_cod_serie) AND (ccae.componente_curricular_id = esd.ref_cod_disciplina))))
     JOIN modules.componente_curricular cc ON ((cc.id = ccae.componente_curricular_id)))
     LEFT JOIN modules.componente_curricular_turma cct ON (((cct.turma_id = t.cod_turma) AND (cct.componente_curricular_id = cc.id))))
  WHERE (
        CASE
            WHEN (EXISTS ( SELECT 1
               FROM modules.componente_curricular_turma
              WHERE (componente_curricular_turma.turma_id = t.cod_turma))) THEN (cct.turma_id IS NOT NULL)
            ELSE true
        END AND (ARRAY[(t.ano)::smallint] <@ esd.anos_letivos));


--
-- Name: view_dados_historico_posicionamento; Type: VIEW; Schema: relatorio; Owner: -
--

CREATE VIEW relatorio.view_dados_historico_posicionamento AS
 SELECT he.ref_cod_aluno,
    public.fcn_upper(hd.nm_disciplina) AS nm_disciplina,
    ( SELECT COALESCE(min(hdd2.ordenamento), 9999) AS "coalesce"
           FROM (pmieducar.historico_escolar hee2
             JOIN pmieducar.historico_disciplinas hdd2 ON (((hdd2.ref_ref_cod_aluno = hee2.ref_cod_aluno) AND (hdd2.ref_sequencial = hee2.sequencial))))
          WHERE ((hee2.ref_cod_aluno = he.ref_cod_aluno) AND (public.fcn_upper(hdd2.nm_disciplina) = public.fcn_upper(hd.nm_disciplina)))) AS order_componente,
    he1.historico_grade_curso_id AS grade_curso1,
    he2.historico_grade_curso_id AS grade_curso2,
    he3.historico_grade_curso_id AS grade_curso3,
    he4.historico_grade_curso_id AS grade_curso4,
    he5.historico_grade_curso_id AS grade_curso5,
    he6.historico_grade_curso_id AS grade_curso6,
    he7.historico_grade_curso_id AS grade_curso7,
    he8.historico_grade_curso_id AS grade_curso8,
    he9.historico_grade_curso_id AS grade_curso9,
    he1.ano AS ano1,
    he2.ano AS ano2,
    he3.ano AS ano3,
    he4.ano AS ano4,
    he5.ano AS ano5,
    he6.ano AS ano6,
    he7.ano AS ano7,
    he8.ano AS ano8,
    he9.ano AS ano9,
    he1.escola AS escola1,
    he2.escola AS escola2,
    he3.escola AS escola3,
    he4.escola AS escola4,
    he5.escola AS escola5,
    he6.escola AS escola6,
    he7.escola AS escola7,
    he8.escola AS escola8,
    he9.escola AS escola9,
    he1.escola_cidade AS escola_cidade1,
    he2.escola_cidade AS escola_cidade2,
    he3.escola_cidade AS escola_cidade3,
    he4.escola_cidade AS escola_cidade4,
    he5.escola_cidade AS escola_cidade5,
    he6.escola_cidade AS escola_cidade6,
    he7.escola_cidade AS escola_cidade7,
    he8.escola_cidade AS escola_cidade8,
    he9.escola_cidade AS escola_cidade9,
    he1.escola_uf AS escola_uf1,
    he2.escola_uf AS escola_uf2,
    he3.escola_uf AS escola_uf3,
    he4.escola_uf AS escola_uf4,
    he5.escola_uf AS escola_uf5,
    he6.escola_uf AS escola_uf6,
    he7.escola_uf AS escola_uf7,
    he8.escola_uf AS escola_uf8,
    he9.escola_uf AS escola_uf9,
    he1.nm_serie AS nm_serie1,
    he2.nm_serie AS nm_serie2,
    he3.nm_serie AS nm_serie3,
    he4.nm_serie AS nm_serie4,
    he5.nm_serie AS nm_serie5,
    he6.nm_serie AS nm_serie6,
    he7.nm_serie AS nm_serie7,
    he8.nm_serie AS nm_serie8,
    he9.nm_serie AS nm_serie9,
    he1.carga_horaria AS ch1,
    he2.carga_horaria AS ch2,
    he3.carga_horaria AS ch3,
    he4.carga_horaria AS ch4,
    he5.carga_horaria AS ch5,
    he6.carga_horaria AS ch6,
    he7.carga_horaria AS ch7,
    he8.carga_horaria AS ch8,
    he9.carga_horaria AS ch9,
    he1.frequencia AS freq1,
    he2.frequencia AS freq2,
    he3.frequencia AS freq3,
    he4.frequencia AS freq4,
    he5.frequencia AS freq5,
    he6.frequencia AS freq6,
    he7.frequencia AS freq7,
    he8.frequencia AS freq8,
    he9.frequencia AS freq9,
    he1.observacao AS obs1,
    he2.observacao AS obs2,
    he3.observacao AS obs3,
    he4.observacao AS obs4,
    he5.observacao AS obs5,
    he6.observacao AS obs6,
    he7.observacao AS obs7,
    he8.observacao AS obs8,
    he9.observacao AS obs9,
    hd1.nota AS nota1,
    hd2.nota AS nota2,
    hd3.nota AS nota3,
    hd4.nota AS nota4,
    hd5.nota AS nota5,
    hd6.nota AS nota6,
    hd7.nota AS nota7,
    hd8.nota AS nota8,
    hd9.nota AS nota9,
    hd1.carga_horaria_disciplina AS chd1,
    hd2.carga_horaria_disciplina AS chd2,
    hd3.carga_horaria_disciplina AS chd3,
    hd4.carga_horaria_disciplina AS chd4,
    hd5.carga_horaria_disciplina AS chd5,
    hd6.carga_horaria_disciplina AS chd6,
    hd7.carga_horaria_disciplina AS chd7,
    hd8.carga_horaria_disciplina AS chd8,
    hd9.carga_horaria_disciplina AS chd9,
    hd1.faltas AS faltas1,
    hd2.faltas AS faltas2,
    hd3.faltas AS faltas3,
    hd4.faltas AS faltas4,
    hd5.faltas AS faltas5,
    hd6.faltas AS faltas6,
    hd7.faltas AS faltas7,
    hd8.faltas AS faltas8,
    hd9.faltas AS faltas9,
        CASE
            WHEN (he1.aceleracao = 1) THEN (
            CASE
                WHEN (he1.aprovado = 1) THEN 'Apro'::text
                WHEN (he1.aprovado = 12) THEN 'AprDep'::text
                WHEN (he1.aprovado = 13) THEN 'AprCo'::text
                WHEN (he1.aprovado = 2) THEN 'Repr'::text
                WHEN (he1.aprovado = 3) THEN 'Curs'::text
                WHEN (he1.aprovado = 4) THEN 'Tran'::text
                WHEN (he1.aprovado = 5) THEN 'Recl'::text
                WHEN (he1.aprovado = 6) THEN 'Aban'::text
                WHEN (he1.aprovado = 14) THEN 'RpFt'::text
                WHEN (he1.aprovado = 15) THEN 'Fal'::text
                ELSE ''::text
            END || ' AC'::text)
            ELSE
            CASE
                WHEN (he1.aprovado = 1) THEN 'Apro'::text
                WHEN (he1.aprovado = 12) THEN 'AprDep'::text
                WHEN (he1.aprovado = 13) THEN 'AprCo'::text
                WHEN (he1.aprovado = 2) THEN 'Repr'::text
                WHEN (he1.aprovado = 3) THEN 'Curs'::text
                WHEN (he1.aprovado = 4) THEN 'Tran'::text
                WHEN (he1.aprovado = 5) THEN 'Recl'::text
                WHEN (he1.aprovado = 6) THEN 'Aban'::text
                WHEN (he1.aprovado = 14) THEN 'RpFt'::text
                WHEN (he1.aprovado = 15) THEN 'Fal'::text
                ELSE ''::text
            END
        END AS status1,
        CASE
            WHEN (he2.aceleracao = 1) THEN (
            CASE
                WHEN (he2.aprovado = 1) THEN 'Apro'::text
                WHEN (he2.aprovado = 12) THEN 'AprDep'::text
                WHEN (he2.aprovado = 13) THEN 'AprCo'::text
                WHEN (he2.aprovado = 2) THEN 'Repr'::text
                WHEN (he2.aprovado = 3) THEN 'Curs'::text
                WHEN (he2.aprovado = 4) THEN 'Tran'::text
                WHEN (he2.aprovado = 5) THEN 'Recl'::text
                WHEN (he2.aprovado = 6) THEN 'Aban'::text
                WHEN (he2.aprovado = 14) THEN 'RpFt'::text
                WHEN (he2.aprovado = 15) THEN 'Fal'::text
                ELSE ''::text
            END || ' AC'::text)
            ELSE
            CASE
                WHEN (he2.aprovado = 1) THEN 'Apro'::text
                WHEN (he2.aprovado = 12) THEN 'AprDep'::text
                WHEN (he2.aprovado = 13) THEN 'AprCo'::text
                WHEN (he2.aprovado = 2) THEN 'Repr'::text
                WHEN (he2.aprovado = 3) THEN 'Curs'::text
                WHEN (he2.aprovado = 4) THEN 'Tran'::text
                WHEN (he2.aprovado = 5) THEN 'Recl'::text
                WHEN (he2.aprovado = 6) THEN 'Aban'::text
                WHEN (he2.aprovado = 14) THEN 'RpFt'::text
                WHEN (he2.aprovado = 15) THEN 'Fal'::text
                ELSE ''::text
            END
        END AS status2,
        CASE
            WHEN (he3.aceleracao = 1) THEN (
            CASE
                WHEN (he3.aprovado = 1) THEN 'Apro'::text
                WHEN (he3.aprovado = 12) THEN 'AprDep'::text
                WHEN (he3.aprovado = 13) THEN 'AprCo'::text
                WHEN (he3.aprovado = 2) THEN 'Repr'::text
                WHEN (he3.aprovado = 3) THEN 'Curs'::text
                WHEN (he3.aprovado = 4) THEN 'Tran'::text
                WHEN (he3.aprovado = 5) THEN 'Recl'::text
                WHEN (he3.aprovado = 6) THEN 'Aban'::text
                WHEN (he3.aprovado = 14) THEN 'RpFt'::text
                WHEN (he3.aprovado = 15) THEN 'Fal'::text
                ELSE ''::text
            END || ' AC'::text)
            ELSE
            CASE
                WHEN (he3.aprovado = 1) THEN 'Apro'::text
                WHEN (he3.aprovado = 12) THEN 'AprDep'::text
                WHEN (he3.aprovado = 13) THEN 'AprCo'::text
                WHEN (he3.aprovado = 2) THEN 'Repr'::text
                WHEN (he3.aprovado = 3) THEN 'Curs'::text
                WHEN (he3.aprovado = 4) THEN 'Tran'::text
                WHEN (he3.aprovado = 5) THEN 'Recl'::text
                WHEN (he3.aprovado = 6) THEN 'Aban'::text
                WHEN (he3.aprovado = 14) THEN 'RpFt'::text
                WHEN (he3.aprovado = 15) THEN 'Fal'::text
                ELSE ''::text
            END
        END AS status3,
        CASE
            WHEN (he4.aceleracao = 1) THEN (
            CASE
                WHEN (he4.aprovado = 1) THEN 'Apro'::text
                WHEN (he4.aprovado = 12) THEN 'AprDep'::text
                WHEN (he4.aprovado = 13) THEN 'AprCo'::text
                WHEN (he4.aprovado = 2) THEN 'Repr'::text
                WHEN (he4.aprovado = 3) THEN 'Curs'::text
                WHEN (he4.aprovado = 4) THEN 'Tran'::text
                WHEN (he4.aprovado = 5) THEN 'Recl'::text
                WHEN (he4.aprovado = 6) THEN 'Aban'::text
                WHEN (he4.aprovado = 14) THEN 'RpFt'::text
                WHEN (he4.aprovado = 15) THEN 'Fal'::text
                ELSE ''::text
            END || ' AC'::text)
            ELSE
            CASE
                WHEN (he4.aprovado = 1) THEN 'Apro'::text
                WHEN (he4.aprovado = 12) THEN 'AprDep'::text
                WHEN (he4.aprovado = 13) THEN 'AprCo'::text
                WHEN (he4.aprovado = 2) THEN 'Repr'::text
                WHEN (he4.aprovado = 3) THEN 'Curs'::text
                WHEN (he4.aprovado = 4) THEN 'Tran'::text
                WHEN (he4.aprovado = 5) THEN 'Recl'::text
                WHEN (he4.aprovado = 6) THEN 'Aban'::text
                WHEN (he4.aprovado = 14) THEN 'RpFt'::text
                WHEN (he4.aprovado = 15) THEN 'Fal'::text
                ELSE ''::text
            END
        END AS status4,
        CASE
            WHEN (he5.aceleracao = 1) THEN (
            CASE
                WHEN (he5.aprovado = 1) THEN 'Apro'::text
                WHEN (he5.aprovado = 12) THEN 'AprDep'::text
                WHEN (he5.aprovado = 13) THEN 'AprCo'::text
                WHEN (he5.aprovado = 2) THEN 'Repr'::text
                WHEN (he5.aprovado = 3) THEN 'Curs'::text
                WHEN (he5.aprovado = 4) THEN 'Tran'::text
                WHEN (he5.aprovado = 5) THEN 'Recl'::text
                WHEN (he5.aprovado = 6) THEN 'Aban'::text
                WHEN (he5.aprovado = 14) THEN 'RpFt'::text
                WHEN (he5.aprovado = 15) THEN 'Fal'::text
                ELSE ''::text
            END || ' AC'::text)
            ELSE
            CASE
                WHEN (he5.aprovado = 1) THEN 'Apro'::text
                WHEN (he5.aprovado = 12) THEN 'AprDep'::text
                WHEN (he5.aprovado = 13) THEN 'AprCo'::text
                WHEN (he5.aprovado = 2) THEN 'Repr'::text
                WHEN (he5.aprovado = 3) THEN 'Curs'::text
                WHEN (he5.aprovado = 4) THEN 'Tran'::text
                WHEN (he5.aprovado = 5) THEN 'Recl'::text
                WHEN (he5.aprovado = 6) THEN 'Aban'::text
                WHEN (he5.aprovado = 14) THEN 'RpFt'::text
                WHEN (he5.aprovado = 15) THEN 'Fal'::text
                ELSE ''::text
            END
        END AS status5,
        CASE
            WHEN (he6.aceleracao = 1) THEN (
            CASE
                WHEN (he6.aprovado = 1) THEN 'Apro'::text
                WHEN (he6.aprovado = 12) THEN 'AprDep'::text
                WHEN (he6.aprovado = 13) THEN 'AprCo'::text
                WHEN (he6.aprovado = 2) THEN 'Repr'::text
                WHEN (he6.aprovado = 3) THEN 'Curs'::text
                WHEN (he6.aprovado = 4) THEN 'Tran'::text
                WHEN (he6.aprovado = 5) THEN 'Recl'::text
                WHEN (he6.aprovado = 6) THEN 'Aban'::text
                WHEN (he6.aprovado = 14) THEN 'RpFt'::text
                WHEN (he6.aprovado = 15) THEN 'Fal'::text
                ELSE ''::text
            END || ' AC'::text)
            ELSE
            CASE
                WHEN (he6.aprovado = 1) THEN 'Apro'::text
                WHEN (he6.aprovado = 12) THEN 'AprDep'::text
                WHEN (he6.aprovado = 13) THEN 'AprCo'::text
                WHEN (he6.aprovado = 2) THEN 'Repr'::text
                WHEN (he6.aprovado = 3) THEN 'Curs'::text
                WHEN (he6.aprovado = 4) THEN 'Tran'::text
                WHEN (he6.aprovado = 5) THEN 'Recl'::text
                WHEN (he6.aprovado = 6) THEN 'Aban'::text
                WHEN (he6.aprovado = 14) THEN 'RpFt'::text
                WHEN (he6.aprovado = 15) THEN 'Fal'::text
                ELSE ''::text
            END
        END AS status6,
        CASE
            WHEN (he7.aceleracao = 1) THEN (
            CASE
                WHEN (he7.aprovado = 1) THEN 'Apro'::text
                WHEN (he7.aprovado = 12) THEN 'AprDep'::text
                WHEN (he7.aprovado = 13) THEN 'AprCo'::text
                WHEN (he7.aprovado = 2) THEN 'Repr'::text
                WHEN (he7.aprovado = 3) THEN 'Curs'::text
                WHEN (he7.aprovado = 4) THEN 'Tran'::text
                WHEN (he7.aprovado = 5) THEN 'Recl'::text
                WHEN (he7.aprovado = 6) THEN 'Aban'::text
                WHEN (he7.aprovado = 14) THEN 'RpFt'::text
                WHEN (he7.aprovado = 15) THEN 'Fal'::text
                ELSE ''::text
            END || ' AC'::text)
            ELSE
            CASE
                WHEN (he7.aprovado = 1) THEN 'Apro'::text
                WHEN (he7.aprovado = 12) THEN 'AprDep'::text
                WHEN (he7.aprovado = 13) THEN 'AprCo'::text
                WHEN (he7.aprovado = 2) THEN 'Repr'::text
                WHEN (he7.aprovado = 3) THEN 'Curs'::text
                WHEN (he7.aprovado = 4) THEN 'Tran'::text
                WHEN (he7.aprovado = 5) THEN 'Recl'::text
                WHEN (he7.aprovado = 6) THEN 'Aban'::text
                WHEN (he7.aprovado = 14) THEN 'RpFt'::text
                WHEN (he7.aprovado = 15) THEN 'Fal'::text
                ELSE ''::text
            END
        END AS status7,
        CASE
            WHEN (he8.aceleracao = 1) THEN (
            CASE
                WHEN (he8.aprovado = 1) THEN 'Apro'::text
                WHEN (he8.aprovado = 12) THEN 'AprDep'::text
                WHEN (he8.aprovado = 13) THEN 'AprCo'::text
                WHEN (he8.aprovado = 2) THEN 'Repr'::text
                WHEN (he8.aprovado = 3) THEN 'Curs'::text
                WHEN (he8.aprovado = 4) THEN 'Tran'::text
                WHEN (he8.aprovado = 5) THEN 'Recl'::text
                WHEN (he8.aprovado = 6) THEN 'Aban'::text
                WHEN (he8.aprovado = 14) THEN 'RpFt'::text
                WHEN (he8.aprovado = 15) THEN 'Fal'::text
                ELSE ''::text
            END || ' AC'::text)
            ELSE
            CASE
                WHEN (he8.aprovado = 1) THEN 'Apro'::text
                WHEN (he8.aprovado = 12) THEN 'AprDep'::text
                WHEN (he8.aprovado = 13) THEN 'AprCo'::text
                WHEN (he8.aprovado = 2) THEN 'Repr'::text
                WHEN (he8.aprovado = 3) THEN 'Curs'::text
                WHEN (he8.aprovado = 4) THEN 'Tran'::text
                WHEN (he8.aprovado = 5) THEN 'Recl'::text
                WHEN (he8.aprovado = 6) THEN 'Aban'::text
                WHEN (he8.aprovado = 14) THEN 'RpFt'::text
                WHEN (he8.aprovado = 15) THEN 'Fal'::text
                ELSE ''::text
            END
        END AS status8,
        CASE
            WHEN (he9.aceleracao = 1) THEN (
            CASE
                WHEN (he9.aprovado = 1) THEN 'Apro'::text
                WHEN (he9.aprovado = 12) THEN 'AprDep'::text
                WHEN (he9.aprovado = 13) THEN 'AprCo'::text
                WHEN (he9.aprovado = 2) THEN 'Repr'::text
                WHEN (he9.aprovado = 3) THEN 'Curs'::text
                WHEN (he9.aprovado = 4) THEN 'Tran'::text
                WHEN (he9.aprovado = 5) THEN 'Recl'::text
                WHEN (he9.aprovado = 6) THEN 'Aban'::text
                WHEN (he9.aprovado = 14) THEN 'RpFt'::text
                WHEN (he9.aprovado = 15) THEN 'Fal'::text
                ELSE ''::text
            END || ' AC'::text)
            ELSE
            CASE
                WHEN (he9.aprovado = 1) THEN 'Apro'::text
                WHEN (he9.aprovado = 12) THEN 'AprDep'::text
                WHEN (he9.aprovado = 13) THEN 'AprCo'::text
                WHEN (he9.aprovado = 2) THEN 'Repr'::text
                WHEN (he9.aprovado = 3) THEN 'Curs'::text
                WHEN (he9.aprovado = 4) THEN 'Tran'::text
                WHEN (he9.aprovado = 5) THEN 'Recl'::text
                WHEN (he9.aprovado = 6) THEN 'Aban'::text
                WHEN (he9.aprovado = 14) THEN 'RpFt'::text
                WHEN (he9.aprovado = 15) THEN 'Fal'::text
                ELSE ''::text
            END
        END AS status9
   FROM (((((((((((((((((((( SELECT hd_1.sequencial,
            hd_1.ref_ref_cod_aluno,
            hd_1.ref_sequencial,
            public.fcn_upper(hd_1.nm_disciplina) AS nm_disciplina,
            hd_1.nota,
            hd_1.faltas,
            hd_1.ordenamento
           FROM pmieducar.historico_disciplinas hd_1) hd
     JOIN pmieducar.historico_escolar he ON (((hd.ref_ref_cod_aluno = he.ref_cod_aluno) AND (hd.ref_sequencial = he.sequencial))))
     LEFT JOIN pmieducar.historico_escolar he1 ON (((he1.ref_cod_aluno = he.ref_cod_aluno) AND (he1.posicao = 1) AND (he1.ativo = 1) AND (he1.sequencial = ( SELECT hee.sequencial
           FROM pmieducar.historico_escolar hee
          WHERE ((hee.ref_cod_aluno = he.ref_cod_aluno) AND (hee.posicao = 1) AND (hee.ativo = 1))
          ORDER BY hee.ano DESC, hee.aprovado
         LIMIT 1)))))
     LEFT JOIN pmieducar.historico_escolar he2 ON (((he2.ref_cod_aluno = he.ref_cod_aluno) AND (he2.posicao = 2) AND (he2.ativo = 1) AND (he2.sequencial = ( SELECT hee.sequencial
           FROM pmieducar.historico_escolar hee
          WHERE ((hee.ref_cod_aluno = he.ref_cod_aluno) AND (hee.posicao = 2) AND (hee.ativo = 1))
          ORDER BY hee.ano DESC, hee.aprovado
         LIMIT 1)))))
     LEFT JOIN pmieducar.historico_escolar he3 ON (((he3.ref_cod_aluno = he.ref_cod_aluno) AND (he3.posicao = 3) AND (he3.ativo = 1) AND (he3.sequencial = ( SELECT hee.sequencial
           FROM pmieducar.historico_escolar hee
          WHERE ((hee.ref_cod_aluno = he.ref_cod_aluno) AND (hee.posicao = 3) AND (hee.ativo = 1))
          ORDER BY hee.ano DESC, hee.aprovado
         LIMIT 1)))))
     LEFT JOIN pmieducar.historico_escolar he4 ON (((he4.ref_cod_aluno = he.ref_cod_aluno) AND (he4.posicao = 4) AND (he4.ativo = 1) AND (he4.sequencial = ( SELECT hee.sequencial
           FROM pmieducar.historico_escolar hee
          WHERE ((hee.ref_cod_aluno = he.ref_cod_aluno) AND (hee.posicao = 4) AND (hee.ativo = 1))
          ORDER BY hee.ano DESC, hee.aprovado
         LIMIT 1)))))
     LEFT JOIN pmieducar.historico_escolar he5 ON (((he5.ref_cod_aluno = he.ref_cod_aluno) AND (he5.posicao = 5) AND (he5.ativo = 1) AND (he5.sequencial = ( SELECT hee.sequencial
           FROM pmieducar.historico_escolar hee
          WHERE ((hee.ref_cod_aluno = he.ref_cod_aluno) AND (hee.posicao = 5) AND (hee.ativo = 1))
          ORDER BY hee.ano DESC, hee.aprovado
         LIMIT 1)))))
     LEFT JOIN pmieducar.historico_escolar he6 ON (((he6.ref_cod_aluno = he.ref_cod_aluno) AND (he6.posicao = 6) AND (he6.ativo = 1) AND (he6.sequencial = ( SELECT hee.sequencial
           FROM pmieducar.historico_escolar hee
          WHERE ((hee.ref_cod_aluno = he.ref_cod_aluno) AND (hee.posicao = 6) AND (hee.ativo = 1))
          ORDER BY hee.ano DESC, hee.aprovado
         LIMIT 1)))))
     LEFT JOIN pmieducar.historico_escolar he7 ON (((he7.ref_cod_aluno = he.ref_cod_aluno) AND (he7.posicao = 7) AND (he7.ativo = 1) AND (he7.sequencial = ( SELECT hee.sequencial
           FROM pmieducar.historico_escolar hee
          WHERE ((hee.ref_cod_aluno = he.ref_cod_aluno) AND (hee.posicao = 7) AND (hee.ativo = 1))
          ORDER BY hee.ano DESC, hee.aprovado
         LIMIT 1)))))
     LEFT JOIN pmieducar.historico_escolar he8 ON (((he8.ref_cod_aluno = he.ref_cod_aluno) AND (he8.posicao = 8) AND (he8.ativo = 1) AND (he8.sequencial = ( SELECT hee.sequencial
           FROM pmieducar.historico_escolar hee
          WHERE ((hee.ref_cod_aluno = he.ref_cod_aluno) AND (hee.posicao = 8) AND (hee.ativo = 1))
          ORDER BY hee.ano DESC, hee.aprovado
         LIMIT 1)))))
     LEFT JOIN pmieducar.historico_escolar he9 ON (((he9.ref_cod_aluno = he.ref_cod_aluno) AND (he9.posicao = 9) AND (he9.ativo = 1) AND (he9.sequencial = ( SELECT hee.sequencial
           FROM pmieducar.historico_escolar hee
          WHERE ((hee.ref_cod_aluno = he.ref_cod_aluno) AND (hee.posicao = 9) AND (hee.ativo = 1))
          ORDER BY hee.ano DESC, hee.aprovado
         LIMIT 1)))))
     LEFT JOIN pmieducar.historico_disciplinas hd1 ON (((hd1.ref_ref_cod_aluno = hd.ref_ref_cod_aluno) AND (public.fcn_upper(hd1.nm_disciplina) = public.fcn_upper(hd.nm_disciplina)) AND (hd1.ref_sequencial = he1.sequencial))))
     LEFT JOIN pmieducar.historico_disciplinas hd2 ON (((hd2.ref_ref_cod_aluno = hd.ref_ref_cod_aluno) AND (public.fcn_upper(hd2.nm_disciplina) = public.fcn_upper(hd.nm_disciplina)) AND (hd2.ref_sequencial = he2.sequencial))))
     LEFT JOIN pmieducar.historico_disciplinas hd3 ON (((hd3.ref_ref_cod_aluno = hd.ref_ref_cod_aluno) AND (public.fcn_upper(hd3.nm_disciplina) = public.fcn_upper(hd.nm_disciplina)) AND (hd3.ref_sequencial = he3.sequencial))))
     LEFT JOIN pmieducar.historico_disciplinas hd4 ON (((hd4.ref_ref_cod_aluno = hd.ref_ref_cod_aluno) AND (public.fcn_upper(hd4.nm_disciplina) = public.fcn_upper(hd.nm_disciplina)) AND (hd4.ref_sequencial = he4.sequencial))))
     LEFT JOIN pmieducar.historico_disciplinas hd5 ON (((hd5.ref_ref_cod_aluno = hd.ref_ref_cod_aluno) AND (public.fcn_upper(hd5.nm_disciplina) = public.fcn_upper(hd.nm_disciplina)) AND (hd5.ref_sequencial = he5.sequencial))))
     LEFT JOIN pmieducar.historico_disciplinas hd6 ON (((hd6.ref_ref_cod_aluno = hd.ref_ref_cod_aluno) AND (public.fcn_upper(hd6.nm_disciplina) = public.fcn_upper(hd.nm_disciplina)) AND (hd6.ref_sequencial = he6.sequencial))))
     LEFT JOIN pmieducar.historico_disciplinas hd7 ON (((hd7.ref_ref_cod_aluno = hd.ref_ref_cod_aluno) AND (public.fcn_upper(hd7.nm_disciplina) = public.fcn_upper(hd.nm_disciplina)) AND (hd7.ref_sequencial = he7.sequencial))))
     LEFT JOIN pmieducar.historico_disciplinas hd8 ON (((hd8.ref_ref_cod_aluno = hd.ref_ref_cod_aluno) AND (public.fcn_upper(hd8.nm_disciplina) = public.fcn_upper(hd.nm_disciplina)) AND (hd8.ref_sequencial = he8.sequencial))))
     LEFT JOIN pmieducar.historico_disciplinas hd9 ON (((hd9.ref_ref_cod_aluno = hd.ref_ref_cod_aluno) AND (public.fcn_upper(hd9.nm_disciplina) = public.fcn_upper(hd.nm_disciplina)) AND (hd9.ref_sequencial = he9.sequencial))))
  WHERE ((he.ativo = 1) AND (he.posicao IS NOT NULL))
  GROUP BY he.ref_cod_aluno, hd.nm_disciplina, he1.historico_grade_curso_id, he2.historico_grade_curso_id, he3.historico_grade_curso_id, he4.historico_grade_curso_id, he5.historico_grade_curso_id, he6.historico_grade_curso_id, he7.historico_grade_curso_id, he8.historico_grade_curso_id, he9.historico_grade_curso_id, he1.ano, he2.ano, he3.ano, he4.ano, he5.ano, he6.ano, he7.ano, he8.ano, he9.ano, he1.escola, he2.escola, he3.escola, he4.escola, he5.escola, he6.escola, he7.escola, he8.escola, he9.escola, he1.escola_cidade, he2.escola_cidade, he3.escola_cidade, he4.escola_cidade, he5.escola_cidade, he6.escola_cidade, he7.escola_cidade, he8.escola_cidade, he9.escola_cidade, he1.escola_uf, he2.escola_uf, he3.escola_uf, he4.escola_uf, he5.escola_uf, he6.escola_uf, he7.escola_uf, he8.escola_uf, he9.escola_uf, he1.nm_serie, he2.nm_serie, he3.nm_serie, he4.nm_serie, he5.nm_serie, he6.nm_serie, he7.nm_serie, he8.nm_serie, he9.nm_serie, he1.carga_horaria, he2.carga_horaria, he3.carga_horaria, he4.carga_horaria, he5.carga_horaria, he6.carga_horaria, he7.carga_horaria, he8.carga_horaria, he9.carga_horaria, he1.frequencia, he2.frequencia, he3.frequencia, he4.frequencia, he5.frequencia, he6.frequencia, he7.frequencia, he8.frequencia, he9.frequencia, he1.observacao, he2.observacao, he3.observacao, he4.observacao, he5.observacao, he6.observacao, he7.observacao, he8.observacao, he9.observacao, hd1.nota, hd2.nota, hd3.nota, hd4.nota, hd5.nota, hd6.nota, hd7.nota, hd8.nota, hd9.nota, hd1.carga_horaria_disciplina, hd2.carga_horaria_disciplina, hd3.carga_horaria_disciplina, hd4.carga_horaria_disciplina, hd5.carga_horaria_disciplina, hd6.carga_horaria_disciplina, hd7.carga_horaria_disciplina, hd8.carga_horaria_disciplina, hd9.carga_horaria_disciplina, hd1.faltas, hd2.faltas, hd3.faltas, hd4.faltas, hd5.faltas, hd6.faltas, hd7.faltas, hd8.faltas, hd9.faltas, he1.aceleracao, he2.aceleracao, he3.aceleracao, he4.aceleracao, he5.aceleracao, he6.aceleracao, he7.aceleracao, he8.aceleracao, he9.aceleracao, he1.aprovado, he2.aprovado, he3.aprovado, he4.aprovado, he5.aprovado, he6.aprovado, he7.aprovado, he8.aprovado, he9.aprovado;


--
-- Name: view_dados_modulo; Type: VIEW; Schema: relatorio; Owner: -
--

CREATE VIEW relatorio.view_dados_modulo AS
( SELECT turma.cod_turma,
    alm.sequencial,
    alm.ref_cod_modulo,
    alm.data_inicio,
    alm.data_fim,
    COALESCE((alm.dias_letivos)::numeric, (0)::numeric) AS dias_letivos
   FROM (((((((pmieducar.instituicao
     JOIN pmieducar.escola ON ((escola.ref_cod_instituicao = instituicao.cod_instituicao)))
     JOIN pmieducar.escola_curso ON (((escola_curso.ativo = 1) AND (escola_curso.ref_cod_escola = escola.cod_escola))))
     JOIN pmieducar.curso ON (((curso.cod_curso = escola_curso.ref_cod_curso) AND (curso.ativo = 1))))
     JOIN pmieducar.escola_serie ON (((escola_serie.ativo = 1) AND (escola_serie.ref_cod_escola = escola.cod_escola))))
     JOIN pmieducar.serie ON (((serie.cod_serie = escola_serie.ref_cod_serie) AND (serie.ativo = 1))))
     JOIN pmieducar.turma ON (((turma.ref_ref_cod_escola = escola.cod_escola) AND (turma.ref_cod_curso = escola_curso.ref_cod_curso) AND (turma.ref_ref_cod_serie = escola_serie.ref_cod_serie) AND (turma.ativo = 1))))
     JOIN pmieducar.ano_letivo_modulo alm ON (((alm.ref_ano = turma.ano) AND (alm.ref_ref_cod_escola = escola.cod_escola))))
  WHERE (curso.padrao_ano_escolar = 1)
  ORDER BY turma.nm_turma, turma.cod_turma, alm.sequencial)
UNION ALL
( SELECT turma.cod_turma,
    tm.sequencial,
    tm.ref_cod_modulo,
    tm.data_inicio,
    tm.data_fim,
    COALESCE(tm.dias_letivos, 0) AS dias_letivos
   FROM (((((((pmieducar.instituicao
     JOIN pmieducar.escola ON ((escola.ref_cod_instituicao = instituicao.cod_instituicao)))
     JOIN pmieducar.escola_curso ON (((escola_curso.ativo = 1) AND (escola_curso.ref_cod_escola = escola.cod_escola))))
     JOIN pmieducar.curso ON (((curso.cod_curso = escola_curso.ref_cod_curso) AND (curso.ativo = 1))))
     JOIN pmieducar.escola_serie ON (((escola_serie.ativo = 1) AND (escola_serie.ref_cod_escola = escola.cod_escola))))
     JOIN pmieducar.serie ON (((serie.cod_serie = escola_serie.ref_cod_serie) AND (serie.ativo = 1))))
     JOIN pmieducar.turma ON (((turma.ref_ref_cod_escola = escola.cod_escola) AND (turma.ref_cod_curso = escola_curso.ref_cod_curso) AND (turma.ref_ref_cod_serie = escola_serie.ref_cod_serie) AND (turma.ativo = 1))))
     JOIN pmieducar.turma_modulo tm ON ((tm.ref_cod_turma = turma.cod_turma)))
  WHERE (curso.padrao_ano_escolar = 0)
  ORDER BY turma.nm_turma, turma.cod_turma, tm.sequencial);


--
-- Name: view_historico_9anos; Type: VIEW; Schema: relatorio; Owner: -
--

CREATE VIEW relatorio.view_historico_9anos AS
 SELECT historico_disciplinas.ref_ref_cod_aluno AS cod_aluno,
    historico_disciplinas.disciplina,
    ( SELECT s.ordenamento
           FROM pmieducar.historico_disciplinas s
          WHERE ((s.ref_ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (btrim((relatorio.get_texto_sem_caracter_especial((s.nm_disciplina)::character varying))::text) = historico_disciplinas.disciplina) AND (s.ordenamento IS NOT NULL))
          ORDER BY s.ref_sequencial DESC
         LIMIT 1) AS ordenamento,
    ((historico_por_disciplina.anos OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '1'::text) || '-ano'::text)))::integer AS ano_1serie,
    ((historico_por_disciplina.anos OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '2'::text) || '-ano'::text)))::integer AS ano_2serie,
    ((historico_por_disciplina.anos OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '3'::text) || '-ano'::text)))::integer AS ano_3serie,
    ((historico_por_disciplina.anos OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '4'::text) || '-ano'::text)))::integer AS ano_4serie,
    ((historico_por_disciplina.anos OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '5'::text) || '-ano'::text)))::integer AS ano_5serie,
    ((historico_por_disciplina.anos OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '6'::text) || '-ano'::text)))::integer AS ano_6serie,
    ((historico_por_disciplina.anos OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '7'::text) || '-ano'::text)))::integer AS ano_7serie,
    ((historico_por_disciplina.anos OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '8'::text) || '-ano'::text)))::integer AS ano_8serie,
    ((historico_por_disciplina.anos OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '9'::text) || '-ano'::text)))::integer AS ano_9serie,
    (historico_por_disciplina.escola OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '1'::text) || '-escola'::text)) AS escola_1serie,
    (historico_por_disciplina.escola OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '2'::text) || '-escola'::text)) AS escola_2serie,
    (historico_por_disciplina.escola OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '3'::text) || '-escola'::text)) AS escola_3serie,
    (historico_por_disciplina.escola OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '4'::text) || '-escola'::text)) AS escola_4serie,
    (historico_por_disciplina.escola OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '5'::text) || '-escola'::text)) AS escola_5serie,
    (historico_por_disciplina.escola OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '6'::text) || '-escola'::text)) AS escola_6serie,
    (historico_por_disciplina.escola OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '7'::text) || '-escola'::text)) AS escola_7serie,
    (historico_por_disciplina.escola OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '8'::text) || '-escola'::text)) AS escola_8serie,
    (historico_por_disciplina.escola OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '9'::text) || '-escola'::text)) AS escola_9serie,
    (historico_por_disciplina.escola_cidade OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '1'::text) || '-escola_cidade'::text)) AS escola_cidade_1serie,
    (historico_por_disciplina.escola_cidade OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '2'::text) || '-escola_cidade'::text)) AS escola_cidade_2serie,
    (historico_por_disciplina.escola_cidade OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '3'::text) || '-escola_cidade'::text)) AS escola_cidade_3serie,
    (historico_por_disciplina.escola_cidade OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '4'::text) || '-escola_cidade'::text)) AS escola_cidade_4serie,
    (historico_por_disciplina.escola_cidade OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '5'::text) || '-escola_cidade'::text)) AS escola_cidade_5serie,
    (historico_por_disciplina.escola_cidade OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '6'::text) || '-escola_cidade'::text)) AS escola_cidade_6serie,
    (historico_por_disciplina.escola_cidade OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '7'::text) || '-escola_cidade'::text)) AS escola_cidade_7serie,
    (historico_por_disciplina.escola_cidade OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '8'::text) || '-escola_cidade'::text)) AS escola_cidade_8serie,
    (historico_por_disciplina.escola_cidade OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '9'::text) || '-escola_cidade'::text)) AS escola_cidade_9serie,
    (historico_por_disciplina.registro OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '1'::text) || '-registro'::text)) AS registro_1serie,
    (historico_por_disciplina.registro OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '2'::text) || '-registro'::text)) AS registro_2serie,
    (historico_por_disciplina.registro OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '3'::text) || '-registro'::text)) AS registro_3serie,
    (historico_por_disciplina.registro OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '4'::text) || '-registro'::text)) AS registro_4serie,
    (historico_por_disciplina.registro OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '5'::text) || '-registro'::text)) AS registro_5serie,
    (historico_por_disciplina.registro OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '6'::text) || '-registro'::text)) AS registro_6serie,
    (historico_por_disciplina.registro OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '7'::text) || '-registro'::text)) AS registro_7serie,
    (historico_por_disciplina.registro OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '8'::text) || '-registro'::text)) AS registro_8serie,
    (historico_por_disciplina.registro OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '9'::text) || '-registro'::text)) AS registro_9serie,
    (historico_por_disciplina.livro OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '1'::text) || '-livro'::text)) AS livro_1serie,
    (historico_por_disciplina.livro OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '2'::text) || '-livro'::text)) AS livro_2serie,
    (historico_por_disciplina.livro OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '3'::text) || '-livro'::text)) AS livro_3serie,
    (historico_por_disciplina.livro OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '4'::text) || '-livro'::text)) AS livro_4serie,
    (historico_por_disciplina.livro OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '5'::text) || '-livro'::text)) AS livro_5serie,
    (historico_por_disciplina.livro OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '6'::text) || '-livro'::text)) AS livro_6serie,
    (historico_por_disciplina.livro OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '7'::text) || '-livro'::text)) AS livro_7serie,
    (historico_por_disciplina.livro OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '8'::text) || '-livro'::text)) AS livro_8serie,
    (historico_por_disciplina.livro OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '9'::text) || '-livro'::text)) AS livro_9serie,
    (historico_por_disciplina.folha OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '1'::text) || '-folha'::text)) AS folha_1serie,
    (historico_por_disciplina.folha OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '2'::text) || '-folha'::text)) AS folha_2serie,
    (historico_por_disciplina.folha OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '3'::text) || '-folha'::text)) AS folha_3serie,
    (historico_por_disciplina.folha OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '4'::text) || '-folha'::text)) AS folha_4serie,
    (historico_por_disciplina.folha OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '5'::text) || '-folha'::text)) AS folha_5serie,
    (historico_por_disciplina.folha OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '6'::text) || '-folha'::text)) AS folha_6serie,
    (historico_por_disciplina.folha OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '7'::text) || '-folha'::text)) AS folha_7serie,
    (historico_por_disciplina.folha OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '8'::text) || '-folha'::text)) AS folha_8serie,
    (historico_por_disciplina.folha OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '9'::text) || '-folha'::text)) AS folha_9serie,
    (historico_por_disciplina.escola_uf OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '1'::text) || '-escola_uf'::text)) AS escola_uf_1serie,
    (historico_por_disciplina.escola_uf OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '2'::text) || '-escola_uf'::text)) AS escola_uf_2serie,
    (historico_por_disciplina.escola_uf OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '3'::text) || '-escola_uf'::text)) AS escola_uf_3serie,
    (historico_por_disciplina.escola_uf OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '4'::text) || '-escola_uf'::text)) AS escola_uf_4serie,
    (historico_por_disciplina.escola_uf OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '5'::text) || '-escola_uf'::text)) AS escola_uf_5serie,
    (historico_por_disciplina.escola_uf OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '6'::text) || '-escola_uf'::text)) AS escola_uf_6serie,
    (historico_por_disciplina.escola_uf OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '7'::text) || '-escola_uf'::text)) AS escola_uf_7serie,
    (historico_por_disciplina.escola_uf OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '8'::text) || '-escola_uf'::text)) AS escola_uf_8serie,
    (historico_por_disciplina.escola_uf OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '9'::text) || '-escola_uf'::text)) AS escola_uf_9serie,
    ((historico_por_disciplina.carga_horaria OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '1'::text) || '-carga_horaria'::text)))::integer AS carga_horaria1,
    ((historico_por_disciplina.carga_horaria OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '2'::text) || '-carga_horaria'::text)))::integer AS carga_horaria2,
    ((historico_por_disciplina.carga_horaria OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '3'::text) || '-carga_horaria'::text)))::integer AS carga_horaria3,
    ((historico_por_disciplina.carga_horaria OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '4'::text) || '-carga_horaria'::text)))::integer AS carga_horaria4,
    ((historico_por_disciplina.carga_horaria OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '5'::text) || '-carga_horaria'::text)))::integer AS carga_horaria5,
    ((historico_por_disciplina.carga_horaria OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '6'::text) || '-carga_horaria'::text)))::integer AS carga_horaria6,
    ((historico_por_disciplina.carga_horaria OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '7'::text) || '-carga_horaria'::text)))::integer AS carga_horaria7,
    ((historico_por_disciplina.carga_horaria OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '8'::text) || '-carga_horaria'::text)))::integer AS carga_horaria8,
    ((historico_por_disciplina.carga_horaria OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '9'::text) || '-carga_horaria'::text)))::integer AS carga_horaria9,
    ((historico_por_disciplina.frequencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '1'::text) || '-frequencia'::text)))::numeric AS frequencia1,
    ((historico_por_disciplina.frequencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '2'::text) || '-frequencia'::text)))::numeric AS frequencia2,
    ((historico_por_disciplina.frequencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '3'::text) || '-frequencia'::text)))::numeric AS frequencia3,
    ((historico_por_disciplina.frequencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '4'::text) || '-frequencia'::text)))::numeric AS frequencia4,
    ((historico_por_disciplina.frequencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '5'::text) || '-frequencia'::text)))::numeric AS frequencia5,
    ((historico_por_disciplina.frequencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '6'::text) || '-frequencia'::text)))::numeric AS frequencia6,
    ((historico_por_disciplina.frequencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '7'::text) || '-frequencia'::text)))::numeric AS frequencia7,
    ((historico_por_disciplina.frequencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '8'::text) || '-frequencia'::text)))::numeric AS frequencia8,
    ((historico_por_disciplina.frequencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '9'::text) || '-frequencia'::text)))::numeric AS frequencia9,
    ((historico_por_disciplina.dias_letivos OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '1'::text) || '-dias_letivos'::text)))::integer AS dias_letivos1,
    ((historico_por_disciplina.dias_letivos OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '2'::text) || '-dias_letivos'::text)))::integer AS dias_letivos2,
    ((historico_por_disciplina.dias_letivos OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '3'::text) || '-dias_letivos'::text)))::integer AS dias_letivos3,
    ((historico_por_disciplina.dias_letivos OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '4'::text) || '-dias_letivos'::text)))::integer AS dias_letivos4,
    ((historico_por_disciplina.dias_letivos OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '5'::text) || '-dias_letivos'::text)))::integer AS dias_letivos5,
    ((historico_por_disciplina.dias_letivos OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '6'::text) || '-dias_letivos'::text)))::integer AS dias_letivos6,
    ((historico_por_disciplina.dias_letivos OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '7'::text) || '-dias_letivos'::text)))::integer AS dias_letivos7,
    ((historico_por_disciplina.dias_letivos OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '8'::text) || '-dias_letivos'::text)))::integer AS dias_letivos8,
    ((historico_por_disciplina.dias_letivos OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '9'::text) || '-dias_letivos'::text)))::integer AS dias_letivos9,
    ((historico_por_disciplina.faltas_globalizadas OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '1'::text) || '-faltas_globalizadas'::text)))::integer AS faltas_globalizadas1,
    ((historico_por_disciplina.faltas_globalizadas OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '2'::text) || '-faltas_globalizadas'::text)))::integer AS faltas_globalizadas2,
    ((historico_por_disciplina.faltas_globalizadas OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '3'::text) || '-faltas_globalizadas'::text)))::integer AS faltas_globalizadas3,
    ((historico_por_disciplina.faltas_globalizadas OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '4'::text) || '-faltas_globalizadas'::text)))::integer AS faltas_globalizadas4,
    ((historico_por_disciplina.faltas_globalizadas OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '5'::text) || '-faltas_globalizadas'::text)))::integer AS faltas_globalizadas5,
    ((historico_por_disciplina.faltas_globalizadas OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '6'::text) || '-faltas_globalizadas'::text)))::integer AS faltas_globalizadas6,
    ((historico_por_disciplina.faltas_globalizadas OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '7'::text) || '-faltas_globalizadas'::text)))::integer AS faltas_globalizadas7,
    ((historico_por_disciplina.faltas_globalizadas OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '8'::text) || '-faltas_globalizadas'::text)))::integer AS faltas_globalizadas8,
    ((historico_por_disciplina.faltas_globalizadas OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '9'::text) || '-faltas_globalizadas'::text)))::integer AS faltas_globalizadas9,
    (historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '1'::text) || '-aprovado'::text)) AS status_serie1,
    (historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '2'::text) || '-aprovado'::text)) AS status_serie2,
    (historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '3'::text) || '-aprovado'::text)) AS status_serie3,
    (historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '4'::text) || '-aprovado'::text)) AS status_serie4,
    (historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '5'::text) || '-aprovado'::text)) AS status_serie5,
    (historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '6'::text) || '-aprovado'::text)) AS status_serie6,
    (historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '7'::text) || '-aprovado'::text)) AS status_serie7,
    (historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '8'::text) || '-aprovado'::text)) AS status_serie8,
    (historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '9'::text) || '-aprovado'::text)) AS status_serie9,
    ((historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '1'::text) || '-aprovado'::text)) ~~ 'Tran%'::text) AS transferido1,
    ((historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '2'::text) || '-aprovado'::text)) ~~ 'Tran%'::text) AS transferido2,
    ((historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '3'::text) || '-aprovado'::text)) ~~ 'Tran%'::text) AS transferido3,
    ((historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '4'::text) || '-aprovado'::text)) ~~ 'Tran%'::text) AS transferido4,
    ((historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '5'::text) || '-aprovado'::text)) ~~ 'Tran%'::text) AS transferido5,
    ((historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '6'::text) || '-aprovado'::text)) ~~ 'Tran%'::text) AS transferido6,
    ((historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '7'::text) || '-aprovado'::text)) ~~ 'Tran%'::text) AS transferido7,
    ((historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '8'::text) || '-aprovado'::text)) ~~ 'Tran%'::text) AS transferido8,
    ((historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '9'::text) || '-aprovado'::text)) ~~ 'Tran%'::text) AS transferido9,
    (historico_por_disciplina.nota OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '1'::text) || '-nota'::text)) AS nota_1serie,
    (historico_por_disciplina.nota OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '2'::text) || '-nota'::text)) AS nota_2serie,
    (historico_por_disciplina.nota OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '3'::text) || '-nota'::text)) AS nota_3serie,
    (historico_por_disciplina.nota OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '4'::text) || '-nota'::text)) AS nota_4serie,
    (historico_por_disciplina.nota OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '5'::text) || '-nota'::text)) AS nota_5serie,
    (historico_por_disciplina.nota OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '6'::text) || '-nota'::text)) AS nota_6serie,
    (historico_por_disciplina.nota OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '7'::text) || '-nota'::text)) AS nota_7serie,
    (historico_por_disciplina.nota OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '8'::text) || '-nota'::text)) AS nota_8serie,
    (historico_por_disciplina.nota OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '9'::text) || '-nota'::text)) AS nota_9serie,
    ((historico_por_disciplina.faltas OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '1'::text) || '-faltas'::text)))::integer AS faltas_1serie,
    ((historico_por_disciplina.faltas OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '2'::text) || '-faltas'::text)))::integer AS faltas_2serie,
    ((historico_por_disciplina.faltas OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '3'::text) || '-faltas'::text)))::integer AS faltas_3serie,
    ((historico_por_disciplina.faltas OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '4'::text) || '-faltas'::text)))::integer AS faltas_4serie,
    ((historico_por_disciplina.faltas OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '5'::text) || '-faltas'::text)))::integer AS faltas_5serie,
    ((historico_por_disciplina.faltas OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '6'::text) || '-faltas'::text)))::integer AS faltas_6serie,
    ((historico_por_disciplina.faltas OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '7'::text) || '-faltas'::text)))::integer AS faltas_7serie,
    ((historico_por_disciplina.faltas OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '8'::text) || '-faltas'::text)))::integer AS faltas_8serie,
    ((historico_por_disciplina.faltas OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '9'::text) || '-faltas'::text)))::integer AS faltas_9serie,
    ((historico_por_disciplina.carga_horaria_disciplina OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '1'::text) || '-carga_horaria_disciplina'::text)))::integer AS carga_horaria_disciplina1,
    ((historico_por_disciplina.carga_horaria_disciplina OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '2'::text) || '-carga_horaria_disciplina'::text)))::integer AS carga_horaria_disciplina2,
    ((historico_por_disciplina.carga_horaria_disciplina OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '3'::text) || '-carga_horaria_disciplina'::text)))::integer AS carga_horaria_disciplina3,
    ((historico_por_disciplina.carga_horaria_disciplina OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '4'::text) || '-carga_horaria_disciplina'::text)))::integer AS carga_horaria_disciplina4,
    ((historico_por_disciplina.carga_horaria_disciplina OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '5'::text) || '-carga_horaria_disciplina'::text)))::integer AS carga_horaria_disciplina5,
    ((historico_por_disciplina.carga_horaria_disciplina OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '6'::text) || '-carga_horaria_disciplina'::text)))::integer AS carga_horaria_disciplina6,
    ((historico_por_disciplina.carga_horaria_disciplina OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '7'::text) || '-carga_horaria_disciplina'::text)))::integer AS carga_horaria_disciplina7,
    ((historico_por_disciplina.carga_horaria_disciplina OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '8'::text) || '-carga_horaria_disciplina'::text)))::integer AS carga_horaria_disciplina8,
    ((historico_por_disciplina.carga_horaria_disciplina OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '9'::text) || '-carga_horaria_disciplina'::text)))::integer AS carga_horaria_disciplina9,
    ((historico_por_disciplina.dependencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '1'::text) || '-dependencia'::text)))::boolean AS disciplina_dependencia1,
    ((historico_por_disciplina.dependencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '2'::text) || '-dependencia'::text)))::boolean AS disciplina_dependencia2,
    ((historico_por_disciplina.dependencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '3'::text) || '-dependencia'::text)))::boolean AS disciplina_dependencia3,
    ((historico_por_disciplina.dependencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '4'::text) || '-dependencia'::text)))::boolean AS disciplina_dependencia4,
    ((historico_por_disciplina.dependencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '5'::text) || '-dependencia'::text)))::boolean AS disciplina_dependencia5,
    ((historico_por_disciplina.dependencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '6'::text) || '-dependencia'::text)))::boolean AS disciplina_dependencia6,
    ((historico_por_disciplina.dependencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '7'::text) || '-dependencia'::text)))::boolean AS disciplina_dependencia7,
    ((historico_por_disciplina.dependencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '8'::text) || '-dependencia'::text)))::boolean AS disciplina_dependencia8,
    ((historico_por_disciplina.dependencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '9'::text) || '-dependencia'::text)))::boolean AS disciplina_dependencia9,
    ( SELECT m.cod_matricula
           FROM pmieducar.matricula m
          WHERE ((m.ano = ( SELECT max(he.ano) AS max
                   FROM pmieducar.historico_escolar he
                  WHERE ((he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.extra_curricular = 0) AND (COALESCE(he.dependencia, false) = false) AND public.isnumeric("substring"((he.nm_serie)::text, 1, 1))))) AND (m.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (m.ativo = 1) AND (m.aprovado = 4))
          ORDER BY m.cod_matricula DESC
         LIMIT 1) AS matricula_transferido,
    ( SELECT public.textcat_all(tabl.obs) AS textcat_all
           FROM ( SELECT phe.observacao AS obs
                   FROM pmieducar.historico_escolar phe
                  WHERE ((phe.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (phe.ativo = 1) AND (phe.extra_curricular = 0) AND (COALESCE(phe.dependencia, false) = false) AND public.isnumeric("substring"((phe.nm_serie)::text, 1, 1)))
                  ORDER BY phe.ano) tabl) AS observacao_all
   FROM ((pmieducar.historico_escolar
     JOIN LATERAL ( SELECT historico_disciplinas_1.sequencial,
            historico_disciplinas_1.ref_ref_cod_aluno,
            historico_disciplinas_1.ref_sequencial,
            btrim((relatorio.get_texto_sem_caracter_especial((historico_disciplinas_1.nm_disciplina)::character varying))::text) AS disciplina,
            historico_disciplinas_1.nota,
            historico_disciplinas_1.faltas
           FROM pmieducar.historico_disciplinas historico_disciplinas_1) historico_disciplinas ON (((historico_escolar.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (historico_escolar.sequencial = historico_disciplinas.ref_sequencial))))
     JOIN LATERAL ( SELECT relatorio.hstore(array_agg(disciplina.ano_key), array_agg(disciplina.ano_value)) AS anos,
            relatorio.hstore(array_agg(disciplina.escola_key), array_agg(disciplina.escola_value)) AS escola,
            relatorio.hstore(array_agg(disciplina.escola_cidade_key), array_agg(disciplina.escola_cidade_value)) AS escola_cidade,
            relatorio.hstore(array_agg(disciplina.registro_key), array_agg(disciplina.registro_value)) AS registro,
            relatorio.hstore(array_agg(disciplina.livro_key), array_agg(disciplina.livro_value)) AS livro,
            relatorio.hstore(array_agg(disciplina.folha_key), array_agg(disciplina.folha_value)) AS folha,
            relatorio.hstore(array_agg(disciplina.escola_uf_key), array_agg(disciplina.escola_uf_value)) AS escola_uf,
            relatorio.hstore(array_agg(disciplina.carga_horaria_key), array_agg(disciplina.carga_horaria_value)) AS carga_horaria,
            relatorio.hstore(array_agg(disciplina.frequencia_key), array_agg(disciplina.frequencia_value)) AS frequencia,
            relatorio.hstore(array_agg(disciplina.dias_letivos_key), array_agg(disciplina.dias_letivos_value)) AS dias_letivos,
            relatorio.hstore(array_agg(disciplina.faltas_globalizadas_key), array_agg(disciplina.faltas_globalizadas_value)) AS faltas_globalizadas,
            relatorio.hstore(array_agg(disciplina.aprovado_key), array_agg(disciplina.aprovado_value)) AS aprovado,
            relatorio.hstore(array_agg(disciplina.nota_key), array_agg(disciplina.nota_value)) AS nota,
            relatorio.hstore(array_agg(disciplina.faltas_key), array_agg(disciplina.faltas_value)) AS faltas,
            relatorio.hstore(array_agg(disciplina.carga_horaria_disciplina_key), array_agg(disciplina.carga_horaria_disciplina_value)) AS carga_horaria_disciplina,
            relatorio.hstore(array_agg(disciplina.dependencia_key), array_agg(disciplina.dependencia_value)) AS dependencia,
            disciplina.disciplina,
            disciplina.ref_cod_aluno
           FROM ( SELECT (((historico_disciplinas_1.disciplina || '-'::text) || "substring"((historico_escolar_1.nm_serie)::text, 1, 1)) || '-ano'::text) AS ano_key,
                    (historico_escolar_1.ano)::text AS ano_value,
                    (((historico_disciplinas_1.disciplina || '-'::text) || "substring"((historico_escolar_1.nm_serie)::text, 1, 1)) || '-escola'::text) AS escola_key,
                    (historico_escolar_1.escola)::text AS escola_value,
                    (((historico_disciplinas_1.disciplina || '-'::text) || "substring"((historico_escolar_1.nm_serie)::text, 1, 1)) || '-escola_cidade'::text) AS escola_cidade_key,
                    (historico_escolar_1.escola_cidade)::text AS escola_cidade_value,
                    (((historico_disciplinas_1.disciplina || '-'::text) || "substring"((historico_escolar_1.nm_serie)::text, 1, 1)) || '-registro'::text) AS registro_key,
                    (historico_escolar_1.registro)::text AS registro_value,
                    (((historico_disciplinas_1.disciplina || '-'::text) || "substring"((historico_escolar_1.nm_serie)::text, 1, 1)) || '-livro'::text) AS livro_key,
                    (historico_escolar_1.livro)::text AS livro_value,
                    (((historico_disciplinas_1.disciplina || '-'::text) || "substring"((historico_escolar_1.nm_serie)::text, 1, 1)) || '-folha'::text) AS folha_key,
                    (historico_escolar_1.folha)::text AS folha_value,
                    (((historico_disciplinas_1.disciplina || '-'::text) || "substring"((historico_escolar_1.nm_serie)::text, 1, 1)) || '-escola_uf'::text) AS escola_uf_key,
                    (historico_escolar_1.escola_uf)::text AS escola_uf_value,
                    (((historico_disciplinas_1.disciplina || '-'::text) || "substring"((historico_escolar_1.nm_serie)::text, 1, 1)) || '-carga_horaria'::text) AS carga_horaria_key,
                    (historico_escolar_1.carga_horaria)::text AS carga_horaria_value,
                    (((historico_disciplinas_1.disciplina || '-'::text) || "substring"((historico_escolar_1.nm_serie)::text, 1, 1)) || '-frequencia'::text) AS frequencia_key,
                    (historico_escolar_1.frequencia)::text AS frequencia_value,
                    (((historico_disciplinas_1.disciplina || '-'::text) || "substring"((historico_escolar_1.nm_serie)::text, 1, 1)) || '-dias_letivos'::text) AS dias_letivos_key,
                    (historico_escolar_1.dias_letivos)::text AS dias_letivos_value,
                    (((historico_disciplinas_1.disciplina || '-'::text) || "substring"((historico_escolar_1.nm_serie)::text, 1, 1)) || '-faltas_globalizadas'::text) AS faltas_globalizadas_key,
                    (historico_escolar_1.faltas_globalizadas)::text AS faltas_globalizadas_value,
                    (((historico_disciplinas_1.disciplina || '-'::text) || "substring"((historico_escolar_1.nm_serie)::text, 1, 1)) || '-aprovado'::text) AS aprovado_key,
                    (
                        CASE (historico_escolar_1.aprovado)::text
                            WHEN '1'::text THEN 'Apro'::text
                            WHEN '12'::text THEN 'AprDep'::text
                            WHEN '13'::text THEN 'AprCo'::text
                            WHEN '2'::text THEN 'Repr'::text
                            WHEN '3'::text THEN 'Curs'::text
                            WHEN '4'::text THEN 'Tran'::text
                            WHEN '5'::text THEN 'Recl'::text
                            WHEN '6'::text THEN 'Aban'::text
                            WHEN '14'::text THEN 'RpFt'::text
                            WHEN '15'::text THEN 'Fal'::text
                            ELSE ''::text
                        END ||
                        CASE
                            WHEN (historico_escolar_1.aceleracao = 1) THEN ' AC'::text
                            ELSE ''::text
                        END) AS aprovado_value,
                    (((historico_disciplinas_1.disciplina || '-'::text) || "substring"((historico_escolar_1.nm_serie)::text, 1, 1)) || '-nota'::text) AS nota_key,
                        CASE
                            WHEN ((public.isnumeric(btrim((historico_disciplinas_1.nota)::text)) = true) AND (("substring"(btrim((historico_disciplinas_1.nota)::text), 1, 1))::integer >= 0) AND (("substring"(btrim((historico_disciplinas_1.nota)::text), 1, 1))::integer <= 9)) THEN replace((historico_disciplinas_1.nota)::text, '.'::text, ','::text)
                            ELSE btrim((historico_disciplinas_1.nota)::text)
                        END AS nota_value,
                    (((historico_disciplinas_1.disciplina || '-'::text) || "substring"((historico_escolar_1.nm_serie)::text, 1, 1)) || '-carga_horaria_disciplina'::text) AS carga_horaria_disciplina_key,
                    (historico_disciplinas_1.carga_horaria_disciplina)::text AS carga_horaria_disciplina_value,
                    (((historico_disciplinas_1.disciplina || '-'::text) || "substring"((historico_escolar_1.nm_serie)::text, 1, 1)) || '-faltas'::text) AS faltas_key,
                    (historico_disciplinas_1.faltas)::text AS faltas_value,
                    (((historico_disciplinas_1.disciplina || '-'::text) || "substring"((historico_escolar_1.nm_serie)::text, 1, 1)) || '-dependencia'::text) AS dependencia_key,
                    (historico_disciplinas_1.dependencia)::text AS dependencia_value,
                    historico_disciplinas_1.disciplina,
                    historico_escolar_1.ref_cod_aluno
                   FROM (pmieducar.historico_escolar historico_escolar_1
                     JOIN LATERAL ( SELECT historico_disciplinas_2.sequencial,
                            historico_disciplinas_2.ref_ref_cod_aluno,
                            historico_disciplinas_2.ref_sequencial,
                            btrim((relatorio.get_texto_sem_caracter_especial((historico_disciplinas_2.nm_disciplina)::character varying))::text) AS disciplina,
                            historico_disciplinas_2.nota,
                            historico_disciplinas_2.faltas,
                            historico_disciplinas_2.carga_horaria_disciplina,
                            historico_disciplinas_2.dependencia
                           FROM pmieducar.historico_disciplinas historico_disciplinas_2) historico_disciplinas_1 ON (((historico_escolar_1.ref_cod_aluno = historico_disciplinas_1.ref_ref_cod_aluno) AND (historico_escolar_1.sequencial = historico_disciplinas_1.ref_sequencial))))
                  WHERE ((historico_escolar_1.extra_curricular = 0) AND (historico_escolar_1.ativo = 1) AND (COALESCE(historico_escolar_1.dependencia, false) = false) AND public.isnumeric("substring"((historico_escolar_1.nm_serie)::text, 1, 1)) AND (historico_disciplinas_1.ref_ref_cod_aluno = historico_disciplinas_1.ref_ref_cod_aluno) AND (historico_escolar_1.sequencial = ( SELECT hee.sequencial
                           FROM pmieducar.historico_escolar hee
                          WHERE (("substring"((hee.nm_serie)::text, 1, 1) = "substring"((historico_escolar_1.nm_serie)::text, 1, 1)) AND (hee.ref_cod_aluno = historico_escolar_1.ref_cod_aluno) AND (hee.extra_curricular = 0) AND (COALESCE(hee.dependencia, false) = false) AND public.isnumeric("substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1))
                          ORDER BY hee.ano DESC, (relatorio.prioridade_historico((hee.aprovado)::numeric))
                         LIMIT 1)))
                  GROUP BY historico_disciplinas_1.disciplina, historico_escolar_1.ano, historico_escolar_1.escola, historico_escolar_1.escola_cidade, historico_escolar_1.registro, historico_escolar_1.livro, historico_escolar_1.folha, historico_escolar_1.escola_uf, historico_escolar_1.carga_horaria, historico_escolar_1.frequencia, historico_escolar_1.dias_letivos, historico_escolar_1.faltas_globalizadas, historico_escolar_1.aprovado, historico_escolar_1.nm_serie, historico_escolar_1.aceleracao, historico_disciplinas_1.nota, historico_disciplinas_1.faltas, historico_disciplinas_1.carga_horaria_disciplina, historico_disciplinas_1.dependencia, historico_escolar_1.ref_cod_aluno
                  ORDER BY historico_escolar_1.ano DESC, (relatorio.prioridade_historico((historico_escolar_1.aprovado)::numeric))) disciplina
          GROUP BY disciplina.disciplina, disciplina.ref_cod_aluno) historico_por_disciplina ON (((historico_por_disciplina.ref_cod_aluno = historico_escolar.ref_cod_aluno) AND (historico_por_disciplina.disciplina = historico_disciplinas.disciplina))))
  WHERE ((historico_escolar.extra_curricular = 0) AND (COALESCE(historico_escolar.dependencia, false) = false) AND public.isnumeric("substring"((historico_escolar.nm_serie)::text, 1, 1)) AND (historico_escolar.ativo = 1))
  GROUP BY historico_disciplinas.disciplina, historico_disciplinas.ref_ref_cod_aluno, historico_por_disciplina.anos, historico_por_disciplina.escola, historico_por_disciplina.escola_cidade, historico_por_disciplina.registro, historico_por_disciplina.livro, historico_por_disciplina.folha, historico_por_disciplina.escola_uf, historico_por_disciplina.carga_horaria, historico_por_disciplina.frequencia, historico_por_disciplina.dias_letivos, historico_por_disciplina.faltas_globalizadas, historico_por_disciplina.aprovado, historico_por_disciplina.nota, historico_por_disciplina.faltas, historico_por_disciplina.carga_horaria_disciplina, historico_por_disciplina.dependencia
  ORDER BY ( SELECT s.ordenamento
           FROM pmieducar.historico_disciplinas s
          WHERE ((s.ref_ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (btrim((relatorio.get_texto_sem_caracter_especial((s.nm_disciplina)::character varying))::text) = historico_disciplinas.disciplina) AND (s.ordenamento IS NOT NULL))
          ORDER BY s.ref_sequencial DESC
         LIMIT 1), historico_disciplinas.disciplina;


--
-- Name: view_historico_9anos_extra_curricular; Type: VIEW; Schema: relatorio; Owner: -
--

CREATE VIEW relatorio.view_historico_9anos_extra_curricular AS
 SELECT ref_ref_cod_aluno AS cod_aluno,
    nm_disciplina AS disciplina,
    ( SELECT
                CASE
                    WHEN (("substring"(btrim((hd.nota)::text), 1, 1) <> (0)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (1)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (2)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (3)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (4)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (5)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (6)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (7)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (8)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (9)::text)) THEN replace((hd.nota)::text, '.'::text, ','::text)
                    WHEN ((to_number(btrim((hd.nota)::text), '999'::text) > (10)::numeric) AND (to_number(btrim((hd.nota)::text), '999'::text) <= (20)::numeric)) THEN replace(btrim((hd.nota)::text), '.'::text, ','::text)
                    ELSE replace("substring"(btrim((hd.nota)::text), 1, 4), '.'::text, ','::text)
                END AS replace
           FROM (pmieducar.historico_disciplinas hd
             JOIN pmieducar.historico_escolar historico_escolar_1 ON ((true AND (historico_escolar_1.ref_cod_aluno = hd.ref_ref_cod_aluno) AND (historico_escolar_1.sequencial = hd.ref_sequencial))))
          WHERE (true AND (hd.ref_ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (public.fcn_upper(hd.nm_disciplina) = public.fcn_upper(historico_disciplinas.nm_disciplina)) AND (historico_escolar_1.ativo = 1) AND (historico_escolar_1.extra_curricular = 1) AND (historico_escolar_1.ano = ( SELECT he.ano
                   FROM pmieducar.historico_escolar he
                  WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.sequencial = ( SELECT max(hee.sequencial) AS max
                           FROM pmieducar.historico_escolar hee
                          WHERE (true AND (hee.ref_cod_aluno = he.ref_cod_aluno) AND ("substring"((he.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he.nm_serie)::text, 1, 1) = (1)::text))
                 LIMIT 1)))
         LIMIT 1) AS nota_1serie,
    ( SELECT
                CASE
                    WHEN (("substring"(btrim((hd.nota)::text), 1, 1) <> (0)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (1)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (2)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (3)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (4)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (5)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (6)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (7)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (8)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (9)::text)) THEN replace((hd.nota)::text, '.'::text, ','::text)
                    WHEN ((to_number(btrim((hd.nota)::text), '999'::text) > (10)::numeric) AND (to_number(btrim((hd.nota)::text), '999'::text) <= (20)::numeric)) THEN replace(btrim((hd.nota)::text), '.'::text, ','::text)
                    ELSE replace("substring"(btrim((hd.nota)::text), 1, 4), '.'::text, ','::text)
                END AS replace
           FROM (pmieducar.historico_disciplinas hd
             JOIN pmieducar.historico_escolar historico_escolar_1 ON ((true AND (historico_escolar_1.ref_cod_aluno = hd.ref_ref_cod_aluno) AND (historico_escolar_1.sequencial = hd.ref_sequencial))))
          WHERE (true AND (hd.ref_ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (public.fcn_upper(hd.nm_disciplina) = public.fcn_upper(historico_disciplinas.nm_disciplina)) AND (historico_escolar_1.ativo = 1) AND (historico_escolar_1.extra_curricular = 1) AND (historico_escolar_1.ano = ( SELECT he.ano
                   FROM pmieducar.historico_escolar he
                  WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.sequencial = ( SELECT max(hee.sequencial) AS max
                           FROM pmieducar.historico_escolar hee
                          WHERE (true AND (hee.ref_cod_aluno = he.ref_cod_aluno) AND ("substring"((he.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he.nm_serie)::text, 1, 1) = (2)::text))
                 LIMIT 1)))
         LIMIT 1) AS nota_2serie,
    ( SELECT
                CASE
                    WHEN (("substring"(btrim((hd.nota)::text), 1, 1) <> (0)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (1)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (2)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (3)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (4)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (5)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (6)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (7)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (8)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (9)::text)) THEN replace((hd.nota)::text, '.'::text, ','::text)
                    WHEN ((to_number(btrim((hd.nota)::text), '999'::text) > (10)::numeric) AND (to_number(btrim((hd.nota)::text), '999'::text) <= (20)::numeric)) THEN replace(btrim((hd.nota)::text), '.'::text, ','::text)
                    ELSE replace("substring"(btrim((hd.nota)::text), 1, 4), '.'::text, ','::text)
                END AS replace
           FROM (pmieducar.historico_disciplinas hd
             JOIN pmieducar.historico_escolar historico_escolar_1 ON ((true AND (historico_escolar_1.ref_cod_aluno = hd.ref_ref_cod_aluno) AND (historico_escolar_1.sequencial = hd.ref_sequencial))))
          WHERE (true AND (hd.ref_ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (public.fcn_upper(hd.nm_disciplina) = public.fcn_upper(historico_disciplinas.nm_disciplina)) AND (historico_escolar_1.ativo = 1) AND (historico_escolar_1.extra_curricular = 1) AND (historico_escolar_1.ano = ( SELECT he.ano
                   FROM pmieducar.historico_escolar he
                  WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.sequencial = ( SELECT max(hee.sequencial) AS max
                           FROM pmieducar.historico_escolar hee
                          WHERE (true AND (hee.ref_cod_aluno = he.ref_cod_aluno) AND ("substring"((he.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he.nm_serie)::text, 1, 1) = (3)::text))
                 LIMIT 1)))
         LIMIT 1) AS nota_3serie,
    ( SELECT
                CASE
                    WHEN (("substring"(btrim((hd.nota)::text), 1, 1) <> (0)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (1)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (2)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (3)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (4)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (5)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (6)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (7)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (8)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (9)::text)) THEN replace((hd.nota)::text, '.'::text, ','::text)
                    WHEN ((to_number(btrim((hd.nota)::text), '999'::text) > (10)::numeric) AND (to_number(btrim((hd.nota)::text), '999'::text) <= (20)::numeric)) THEN replace(btrim((hd.nota)::text), '.'::text, ','::text)
                    ELSE replace("substring"(btrim((hd.nota)::text), 1, 4), '.'::text, ','::text)
                END AS replace
           FROM (pmieducar.historico_disciplinas hd
             JOIN pmieducar.historico_escolar historico_escolar_1 ON ((true AND (historico_escolar_1.ref_cod_aluno = hd.ref_ref_cod_aluno) AND (historico_escolar_1.sequencial = hd.ref_sequencial))))
          WHERE (true AND (hd.ref_ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (public.fcn_upper(hd.nm_disciplina) = public.fcn_upper(historico_disciplinas.nm_disciplina)) AND (historico_escolar_1.ativo = 1) AND (historico_escolar_1.extra_curricular = 1) AND (historico_escolar_1.ano = ( SELECT he.ano
                   FROM pmieducar.historico_escolar he
                  WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.sequencial = ( SELECT max(hee.sequencial) AS max
                           FROM pmieducar.historico_escolar hee
                          WHERE (true AND (hee.ref_cod_aluno = he.ref_cod_aluno) AND ("substring"((he.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he.nm_serie)::text, 1, 1) = (4)::text))
                 LIMIT 1)))
         LIMIT 1) AS nota_4serie,
    ( SELECT
                CASE
                    WHEN (("substring"(btrim((hd.nota)::text), 1, 1) <> (0)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (1)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (2)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (3)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (4)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (5)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (6)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (7)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (8)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (9)::text)) THEN replace((hd.nota)::text, '.'::text, ','::text)
                    WHEN ((to_number(btrim((hd.nota)::text), '999'::text) > (10)::numeric) AND (to_number(btrim((hd.nota)::text), '999'::text) <= (20)::numeric)) THEN replace(btrim((hd.nota)::text), '.'::text, ','::text)
                    ELSE replace("substring"(btrim((hd.nota)::text), 1, 4), '.'::text, ','::text)
                END AS replace
           FROM (pmieducar.historico_disciplinas hd
             JOIN pmieducar.historico_escolar historico_escolar_1 ON ((true AND (historico_escolar_1.ref_cod_aluno = hd.ref_ref_cod_aluno) AND (historico_escolar_1.sequencial = hd.ref_sequencial))))
          WHERE (true AND (hd.ref_ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (public.fcn_upper(hd.nm_disciplina) = public.fcn_upper(historico_disciplinas.nm_disciplina)) AND (historico_escolar_1.ativo = 1) AND (historico_escolar_1.extra_curricular = 1) AND (historico_escolar_1.ano = ( SELECT he.ano
                   FROM pmieducar.historico_escolar he
                  WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.sequencial = ( SELECT max(hee.sequencial) AS max
                           FROM pmieducar.historico_escolar hee
                          WHERE (true AND (hee.ref_cod_aluno = he.ref_cod_aluno) AND ("substring"((he.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he.nm_serie)::text, 1, 1) = (5)::text))
                 LIMIT 1)))
         LIMIT 1) AS nota_5serie,
    ( SELECT
                CASE
                    WHEN (("substring"(btrim((hd.nota)::text), 1, 1) <> (0)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (1)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (2)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (3)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (4)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (5)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (6)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (7)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (8)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (9)::text)) THEN replace((hd.nota)::text, '.'::text, ','::text)
                    WHEN ((to_number(btrim((hd.nota)::text), '999'::text) > (10)::numeric) AND (to_number(btrim((hd.nota)::text), '999'::text) <= (20)::numeric)) THEN replace(btrim((hd.nota)::text), '.'::text, ','::text)
                    ELSE replace("substring"(btrim((hd.nota)::text), 1, 4), '.'::text, ','::text)
                END AS replace
           FROM (pmieducar.historico_disciplinas hd
             JOIN pmieducar.historico_escolar historico_escolar_1 ON ((true AND (historico_escolar_1.ref_cod_aluno = hd.ref_ref_cod_aluno) AND (historico_escolar_1.sequencial = hd.ref_sequencial))))
          WHERE (true AND (hd.ref_ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (public.fcn_upper(hd.nm_disciplina) = public.fcn_upper(historico_disciplinas.nm_disciplina)) AND (historico_escolar_1.ativo = 1) AND (historico_escolar_1.extra_curricular = 1) AND (historico_escolar_1.ano = ( SELECT he.ano
                   FROM pmieducar.historico_escolar he
                  WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.sequencial = ( SELECT max(hee.sequencial) AS max
                           FROM pmieducar.historico_escolar hee
                          WHERE (true AND (hee.ref_cod_aluno = he.ref_cod_aluno) AND ("substring"((he.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he.nm_serie)::text, 1, 1) = (6)::text))
                 LIMIT 1)))
         LIMIT 1) AS nota_6serie,
    ( SELECT
                CASE
                    WHEN (("substring"(btrim((hd.nota)::text), 1, 1) <> (0)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (1)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (2)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (3)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (4)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (5)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (6)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (7)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (8)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (9)::text)) THEN replace((hd.nota)::text, '.'::text, ','::text)
                    WHEN ((to_number(btrim((hd.nota)::text), '999'::text) > (10)::numeric) AND (to_number(btrim((hd.nota)::text), '999'::text) <= (20)::numeric)) THEN replace(btrim((hd.nota)::text), '.'::text, ','::text)
                    ELSE replace("substring"(btrim((hd.nota)::text), 1, 4), '.'::text, ','::text)
                END AS replace
           FROM (pmieducar.historico_disciplinas hd
             JOIN pmieducar.historico_escolar historico_escolar_1 ON ((true AND (historico_escolar_1.ref_cod_aluno = hd.ref_ref_cod_aluno) AND (historico_escolar_1.sequencial = hd.ref_sequencial))))
          WHERE (true AND (hd.ref_ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (public.fcn_upper(hd.nm_disciplina) = public.fcn_upper(historico_disciplinas.nm_disciplina)) AND (historico_escolar_1.ativo = 1) AND (historico_escolar_1.extra_curricular = 1) AND (historico_escolar_1.ano = ( SELECT he.ano
                   FROM pmieducar.historico_escolar he
                  WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.sequencial = ( SELECT max(hee.sequencial) AS max
                           FROM pmieducar.historico_escolar hee
                          WHERE (true AND (hee.ref_cod_aluno = he.ref_cod_aluno) AND ("substring"((he.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he.nm_serie)::text, 1, 1) = (7)::text))
                 LIMIT 1)))
         LIMIT 1) AS nota_7serie,
    ( SELECT
                CASE
                    WHEN (("substring"(btrim((hd.nota)::text), 1, 1) <> (0)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (1)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (2)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (3)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (4)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (5)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (6)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (7)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (8)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (9)::text)) THEN replace((hd.nota)::text, '.'::text, ','::text)
                    WHEN ((to_number(btrim((hd.nota)::text), '999'::text) > (10)::numeric) AND (to_number(btrim((hd.nota)::text), '999'::text) <= (20)::numeric)) THEN replace(btrim((hd.nota)::text), '.'::text, ','::text)
                    ELSE replace("substring"(btrim((hd.nota)::text), 1, 4), '.'::text, ','::text)
                END AS replace
           FROM (pmieducar.historico_disciplinas hd
             JOIN pmieducar.historico_escolar historico_escolar_1 ON ((true AND (historico_escolar_1.ref_cod_aluno = hd.ref_ref_cod_aluno) AND (historico_escolar_1.sequencial = hd.ref_sequencial))))
          WHERE (true AND (hd.ref_ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (public.fcn_upper(hd.nm_disciplina) = public.fcn_upper(historico_disciplinas.nm_disciplina)) AND (historico_escolar_1.ativo = 1) AND (historico_escolar_1.extra_curricular = 1) AND (historico_escolar_1.ano = ( SELECT he.ano
                   FROM pmieducar.historico_escolar he
                  WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.sequencial = ( SELECT max(hee.sequencial) AS max
                           FROM pmieducar.historico_escolar hee
                          WHERE (true AND (hee.ref_cod_aluno = he.ref_cod_aluno) AND ("substring"((he.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he.nm_serie)::text, 1, 1) = (8)::text))
                 LIMIT 1)))
         LIMIT 1) AS nota_8serie,
    ( SELECT
                CASE
                    WHEN (("substring"(btrim((hd.nota)::text), 1, 1) <> (0)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (1)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (2)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (3)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (4)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (5)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (6)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (7)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (8)::text) AND ("substring"(btrim((hd.nota)::text), 1, 1) <> (9)::text)) THEN replace((hd.nota)::text, '.'::text, ','::text)
                    WHEN ((to_number(btrim((hd.nota)::text), '999'::text) > (10)::numeric) AND (to_number(btrim((hd.nota)::text), '999'::text) <= (20)::numeric)) THEN replace(btrim((hd.nota)::text), '.'::text, ','::text)
                    ELSE replace("substring"(btrim((hd.nota)::text), 1, 4), '.'::text, ','::text)
                END AS replace
           FROM (pmieducar.historico_disciplinas hd
             JOIN pmieducar.historico_escolar historico_escolar_1 ON ((true AND (historico_escolar_1.ref_cod_aluno = hd.ref_ref_cod_aluno) AND (historico_escolar_1.sequencial = hd.ref_sequencial))))
          WHERE (true AND (hd.ref_ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (public.fcn_upper(hd.nm_disciplina) = public.fcn_upper(historico_disciplinas.nm_disciplina)) AND (historico_escolar_1.ativo = 1) AND (historico_escolar_1.extra_curricular = 1) AND (historico_escolar_1.ano = ( SELECT he.ano
                   FROM pmieducar.historico_escolar he
                  WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.sequencial = ( SELECT max(hee.sequencial) AS max
                           FROM pmieducar.historico_escolar hee
                          WHERE (true AND (hee.ref_cod_aluno = he.ref_cod_aluno) AND ("substring"((he.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he.nm_serie)::text, 1, 1) = (9)::text))
                 LIMIT 1)))
         LIMIT 1) AS nota_9serie,
    ( SELECT he.ano
           FROM pmieducar.historico_escolar he
          WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.sequencial = ( SELECT max(hee.sequencial) AS max
                   FROM pmieducar.historico_escolar hee
                  WHERE (true AND (hee.ref_cod_aluno = he.ref_cod_aluno) AND ("substring"((he.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he.nm_serie)::text, 1, 1) = (1)::text))
         LIMIT 1) AS ano_1serie,
    ( SELECT he.ano
           FROM pmieducar.historico_escolar he
          WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.sequencial = ( SELECT max(hee.sequencial) AS max
                   FROM pmieducar.historico_escolar hee
                  WHERE (true AND (hee.ref_cod_aluno = he.ref_cod_aluno) AND ("substring"((he.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he.nm_serie)::text, 1, 1) = (2)::text))
         LIMIT 1) AS ano_2serie,
    ( SELECT he.ano
           FROM pmieducar.historico_escolar he
          WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.sequencial = ( SELECT max(hee.sequencial) AS max
                   FROM pmieducar.historico_escolar hee
                  WHERE (true AND (hee.ref_cod_aluno = he.ref_cod_aluno) AND ("substring"((he.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he.nm_serie)::text, 1, 1) = (3)::text))
         LIMIT 1) AS ano_3serie,
    ( SELECT he.ano
           FROM pmieducar.historico_escolar he
          WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.sequencial = ( SELECT max(hee.sequencial) AS max
                   FROM pmieducar.historico_escolar hee
                  WHERE (true AND (hee.ref_cod_aluno = he.ref_cod_aluno) AND ("substring"((he.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he.nm_serie)::text, 1, 1) = (4)::text))
         LIMIT 1) AS ano_4serie,
    ( SELECT he.ano
           FROM pmieducar.historico_escolar he
          WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.sequencial = ( SELECT max(hee.sequencial) AS max
                   FROM pmieducar.historico_escolar hee
                  WHERE (true AND (hee.ref_cod_aluno = he.ref_cod_aluno) AND ("substring"((he.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he.nm_serie)::text, 1, 1) = (5)::text))
         LIMIT 1) AS ano_5serie,
    ( SELECT he.ano
           FROM pmieducar.historico_escolar he
          WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.sequencial = ( SELECT max(hee.sequencial) AS max
                   FROM pmieducar.historico_escolar hee
                  WHERE (true AND (hee.ref_cod_aluno = he.ref_cod_aluno) AND ("substring"((he.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he.nm_serie)::text, 1, 1) = (6)::text))
         LIMIT 1) AS ano_6serie,
    ( SELECT he.ano
           FROM pmieducar.historico_escolar he
          WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.sequencial = ( SELECT max(hee.sequencial) AS max
                   FROM pmieducar.historico_escolar hee
                  WHERE (true AND (hee.ref_cod_aluno = he.ref_cod_aluno) AND ("substring"((he.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he.nm_serie)::text, 1, 1) = (7)::text))
         LIMIT 1) AS ano_7serie,
    ( SELECT he.ano
           FROM pmieducar.historico_escolar he
          WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.sequencial = ( SELECT max(hee.sequencial) AS max
                   FROM pmieducar.historico_escolar hee
                  WHERE (true AND (hee.ref_cod_aluno = he.ref_cod_aluno) AND ("substring"((he.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he.nm_serie)::text, 1, 1) = (8)::text))
         LIMIT 1) AS ano_8serie,
    ( SELECT he.ano
           FROM pmieducar.historico_escolar he
          WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.sequencial = ( SELECT max(hee.sequencial) AS max
                   FROM pmieducar.historico_escolar hee
                  WHERE (true AND (hee.ref_cod_aluno = he.ref_cod_aluno) AND ("substring"((he.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he.nm_serie)::text, 1, 1) = (9)::text))
         LIMIT 1) AS ano_9serie,
    ( SELECT DISTINCT (he.aprovado = 4)
           FROM pmieducar.historico_escolar he
          WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.extra_curricular = 1) AND (he.ano = ( SELECT he_1.ano
                   FROM pmieducar.historico_escolar he_1
                  WHERE (true AND (he_1.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he_1.ativo = 1) AND (he_1.sequencial = ( SELECT max(hee.sequencial) AS max
                           FROM pmieducar.historico_escolar hee
                          WHERE (true AND (hee.ref_cod_aluno = he_1.ref_cod_aluno) AND ("substring"((he_1.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he_1.nm_serie)::text, 1, 1) = (1)::text))
                 LIMIT 1)))
          ORDER BY (he.aprovado = 4)
         LIMIT 1) AS transferido1,
    ( SELECT DISTINCT (he.aprovado = 4)
           FROM pmieducar.historico_escolar he
          WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.extra_curricular = 1) AND (he.ano = ( SELECT he_1.ano
                   FROM pmieducar.historico_escolar he_1
                  WHERE (true AND (he_1.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he_1.ativo = 1) AND (he_1.sequencial = ( SELECT max(hee.sequencial) AS max
                           FROM pmieducar.historico_escolar hee
                          WHERE (true AND (hee.ref_cod_aluno = he_1.ref_cod_aluno) AND ("substring"((he_1.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he_1.nm_serie)::text, 1, 1) = (2)::text))
                 LIMIT 1)))
          ORDER BY (he.aprovado = 4)
         LIMIT 1) AS transferido2,
    ( SELECT DISTINCT (he.aprovado = 4)
           FROM pmieducar.historico_escolar he
          WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.extra_curricular = 1) AND (he.ano = ( SELECT he_1.ano
                   FROM pmieducar.historico_escolar he_1
                  WHERE (true AND (he_1.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he_1.ativo = 1) AND (he_1.sequencial = ( SELECT max(hee.sequencial) AS max
                           FROM pmieducar.historico_escolar hee
                          WHERE (true AND (hee.ref_cod_aluno = he_1.ref_cod_aluno) AND ("substring"((he_1.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he_1.nm_serie)::text, 1, 1) = (3)::text))
                 LIMIT 1)))
          ORDER BY (he.aprovado = 4)
         LIMIT 1) AS transferido3,
    ( SELECT DISTINCT (he.aprovado = 4)
           FROM pmieducar.historico_escolar he
          WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.extra_curricular = 1) AND (he.ano = ( SELECT he_1.ano
                   FROM pmieducar.historico_escolar he_1
                  WHERE (true AND (he_1.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he_1.ativo = 1) AND (he_1.sequencial = ( SELECT max(hee.sequencial) AS max
                           FROM pmieducar.historico_escolar hee
                          WHERE (true AND (hee.ref_cod_aluno = he_1.ref_cod_aluno) AND ("substring"((he_1.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he_1.nm_serie)::text, 1, 1) = (4)::text))
                 LIMIT 1)))
          ORDER BY (he.aprovado = 4)
         LIMIT 1) AS transferido4,
    ( SELECT DISTINCT (he.aprovado = 4)
           FROM pmieducar.historico_escolar he
          WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.extra_curricular = 1) AND (he.ano = ( SELECT he_1.ano
                   FROM pmieducar.historico_escolar he_1
                  WHERE (true AND (he_1.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he_1.ativo = 1) AND (he_1.sequencial = ( SELECT max(hee.sequencial) AS max
                           FROM pmieducar.historico_escolar hee
                          WHERE (true AND (hee.ref_cod_aluno = he_1.ref_cod_aluno) AND ("substring"((he_1.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he_1.nm_serie)::text, 1, 1) = (5)::text))
                 LIMIT 1)))
          ORDER BY (he.aprovado = 4)
         LIMIT 1) AS transferido5,
    ( SELECT DISTINCT (he.aprovado = 4)
           FROM pmieducar.historico_escolar he
          WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.extra_curricular = 1) AND (he.ano = ( SELECT he_1.ano
                   FROM pmieducar.historico_escolar he_1
                  WHERE (true AND (he_1.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he_1.ativo = 1) AND (he_1.sequencial = ( SELECT max(hee.sequencial) AS max
                           FROM pmieducar.historico_escolar hee
                          WHERE (true AND (hee.ref_cod_aluno = he_1.ref_cod_aluno) AND ("substring"((he_1.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he_1.nm_serie)::text, 1, 1) = (6)::text))
                 LIMIT 1)))
          ORDER BY (he.aprovado = 4)
         LIMIT 1) AS transferido6,
    ( SELECT DISTINCT (he.aprovado = 4)
           FROM pmieducar.historico_escolar he
          WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.extra_curricular = 1) AND (he.ano = ( SELECT he_1.ano
                   FROM pmieducar.historico_escolar he_1
                  WHERE (true AND (he_1.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he_1.ativo = 1) AND (he_1.sequencial = ( SELECT max(hee.sequencial) AS max
                           FROM pmieducar.historico_escolar hee
                          WHERE (true AND (hee.ref_cod_aluno = he_1.ref_cod_aluno) AND ("substring"((he_1.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he_1.nm_serie)::text, 1, 1) = (7)::text))
                 LIMIT 1)))
          ORDER BY (he.aprovado = 4)
         LIMIT 1) AS transferido7,
    ( SELECT DISTINCT (he.aprovado = 4)
           FROM pmieducar.historico_escolar he
          WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.extra_curricular = 1) AND (he.ano = ( SELECT he_1.ano
                   FROM pmieducar.historico_escolar he_1
                  WHERE (true AND (he_1.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he_1.ativo = 1) AND (he_1.sequencial = ( SELECT max(hee.sequencial) AS max
                           FROM pmieducar.historico_escolar hee
                          WHERE (true AND (hee.ref_cod_aluno = he_1.ref_cod_aluno) AND ("substring"((he_1.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he_1.nm_serie)::text, 1, 1) = (8)::text))
                 LIMIT 1)))
          ORDER BY (he.aprovado = 4)
         LIMIT 1) AS transferido8,
    ( SELECT DISTINCT (he.aprovado = 4)
           FROM pmieducar.historico_escolar he
          WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.extra_curricular = 1) AND (he.ano = ( SELECT he_1.ano
                   FROM pmieducar.historico_escolar he_1
                  WHERE (true AND (he_1.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he_1.ativo = 1) AND (he_1.sequencial = ( SELECT max(hee.sequencial) AS max
                           FROM pmieducar.historico_escolar hee
                          WHERE (true AND (hee.ref_cod_aluno = he_1.ref_cod_aluno) AND ("substring"((he_1.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he_1.nm_serie)::text, 1, 1) = (9)::text))
                 LIMIT 1)))
          ORDER BY (he.aprovado = 4)
         LIMIT 1) AS transferido9,
    ( SELECT he.carga_horaria
           FROM pmieducar.historico_escolar he
          WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.extra_curricular = 1) AND (he.ano = ( SELECT he_1.ano
                   FROM pmieducar.historico_escolar he_1
                  WHERE (true AND (he_1.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he_1.ativo = 1) AND (he_1.sequencial = ( SELECT max(hee.sequencial) AS max
                           FROM pmieducar.historico_escolar hee
                          WHERE (true AND (hee.ref_cod_aluno = he_1.ref_cod_aluno) AND ("substring"((he_1.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he_1.nm_serie)::text, 1, 1) = (1)::text))
                 LIMIT 1)))
         LIMIT 1) AS carga_horaria1,
    ( SELECT he.carga_horaria
           FROM pmieducar.historico_escolar he
          WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.extra_curricular = 1) AND (he.ano = ( SELECT he_1.ano
                   FROM pmieducar.historico_escolar he_1
                  WHERE (true AND (he_1.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he_1.ativo = 1) AND (he_1.sequencial = ( SELECT max(hee.sequencial) AS max
                           FROM pmieducar.historico_escolar hee
                          WHERE (true AND (hee.ref_cod_aluno = he_1.ref_cod_aluno) AND ("substring"((he_1.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he_1.nm_serie)::text, 1, 1) = (2)::text))
                 LIMIT 1)))
         LIMIT 1) AS carga_horaria2,
    ( SELECT he.carga_horaria
           FROM pmieducar.historico_escolar he
          WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.extra_curricular = 1) AND (he.ano = ( SELECT he_1.ano
                   FROM pmieducar.historico_escolar he_1
                  WHERE (true AND (he_1.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he_1.ativo = 1) AND (he_1.sequencial = ( SELECT max(hee.sequencial) AS max
                           FROM pmieducar.historico_escolar hee
                          WHERE (true AND (hee.ref_cod_aluno = he_1.ref_cod_aluno) AND ("substring"((he_1.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he_1.nm_serie)::text, 1, 1) = (3)::text))
                 LIMIT 1)))
         LIMIT 1) AS carga_horaria3,
    ( SELECT he.carga_horaria
           FROM pmieducar.historico_escolar he
          WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.extra_curricular = 1) AND (he.ano = ( SELECT he_1.ano
                   FROM pmieducar.historico_escolar he_1
                  WHERE (true AND (he_1.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he_1.ativo = 1) AND (he_1.sequencial = ( SELECT max(hee.sequencial) AS max
                           FROM pmieducar.historico_escolar hee
                          WHERE (true AND (hee.ref_cod_aluno = he_1.ref_cod_aluno) AND ("substring"((he_1.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he_1.nm_serie)::text, 1, 1) = (4)::text))
                 LIMIT 1)))
         LIMIT 1) AS carga_horaria4,
    ( SELECT he.carga_horaria
           FROM pmieducar.historico_escolar he
          WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.extra_curricular = 1) AND (he.ano = ( SELECT he_1.ano
                   FROM pmieducar.historico_escolar he_1
                  WHERE (true AND (he_1.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he_1.ativo = 1) AND (he_1.sequencial = ( SELECT max(hee.sequencial) AS max
                           FROM pmieducar.historico_escolar hee
                          WHERE (true AND (hee.ref_cod_aluno = he_1.ref_cod_aluno) AND ("substring"((he_1.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he_1.nm_serie)::text, 1, 1) = (5)::text))
                 LIMIT 1)))
         LIMIT 1) AS carga_horaria5,
    ( SELECT he.carga_horaria
           FROM pmieducar.historico_escolar he
          WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.extra_curricular = 1) AND (he.ano = ( SELECT he_1.ano
                   FROM pmieducar.historico_escolar he_1
                  WHERE (true AND (he_1.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he_1.ativo = 1) AND (he_1.sequencial = ( SELECT max(hee.sequencial) AS max
                           FROM pmieducar.historico_escolar hee
                          WHERE (true AND (hee.ref_cod_aluno = he_1.ref_cod_aluno) AND ("substring"((he_1.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he_1.nm_serie)::text, 1, 1) = (6)::text))
                 LIMIT 1)))
         LIMIT 1) AS carga_horaria6,
    ( SELECT he.carga_horaria
           FROM pmieducar.historico_escolar he
          WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.extra_curricular = 1) AND (he.ano = ( SELECT he_1.ano
                   FROM pmieducar.historico_escolar he_1
                  WHERE (true AND (he_1.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he_1.ativo = 1) AND (he_1.sequencial = ( SELECT max(hee.sequencial) AS max
                           FROM pmieducar.historico_escolar hee
                          WHERE (true AND (hee.ref_cod_aluno = he_1.ref_cod_aluno) AND ("substring"((he_1.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he_1.nm_serie)::text, 1, 1) = (7)::text))
                 LIMIT 1)))
         LIMIT 1) AS carga_horaria7,
    ( SELECT he.carga_horaria
           FROM pmieducar.historico_escolar he
          WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.extra_curricular = 1) AND (he.ano = ( SELECT he_1.ano
                   FROM pmieducar.historico_escolar he_1
                  WHERE (true AND (he_1.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he_1.ativo = 1) AND (he_1.sequencial = ( SELECT max(hee.sequencial) AS max
                           FROM pmieducar.historico_escolar hee
                          WHERE (true AND (hee.ref_cod_aluno = he_1.ref_cod_aluno) AND ("substring"((he_1.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he_1.nm_serie)::text, 1, 1) = (8)::text))
                 LIMIT 1)))
         LIMIT 1) AS carga_horaria8,
    ( SELECT he.carga_horaria
           FROM pmieducar.historico_escolar he
          WHERE (true AND (he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.extra_curricular = 1) AND (he.ano = ( SELECT he_1.ano
                   FROM pmieducar.historico_escolar he_1
                  WHERE (true AND (he_1.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he_1.ativo = 1) AND (he_1.sequencial = ( SELECT max(hee.sequencial) AS max
                           FROM pmieducar.historico_escolar hee
                          WHERE (true AND (hee.ref_cod_aluno = he_1.ref_cod_aluno) AND ("substring"((he_1.nm_serie)::text, 1, 1) = "substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1) AND (hee.extra_curricular = 0)))) AND ("substring"((he_1.nm_serie)::text, 1, 1) = (9)::text))
                 LIMIT 1)))
         LIMIT 1) AS carga_horaria9
   FROM ( SELECT historico_escolar.ref_cod_aluno,
            public.fcn_upper(historico_disciplinas_1.nm_disciplina) AS nm_disciplina,
            historico_escolar.sequencial,
            historico_disciplinas_1.ref_sequencial,
            historico_disciplinas_1.ref_ref_cod_aluno,
            historico_escolar.extra_curricular,
            historico_escolar.ativo
           FROM (pmieducar.historico_disciplinas historico_disciplinas_1
             JOIN pmieducar.historico_escolar ON ((true AND (historico_escolar.ref_cod_aluno = historico_disciplinas_1.ref_ref_cod_aluno) AND (historico_escolar.sequencial = historico_disciplinas_1.ref_sequencial))))) historico_disciplinas
  WHERE (true AND (extra_curricular = 1) AND (ativo = 1))
  GROUP BY nm_disciplina, ref_cod_aluno, ref_ref_cod_aluno
  ORDER BY nm_disciplina;


--
-- Name: view_historico_series_anos; Type: VIEW; Schema: relatorio; Owner: -
--

CREATE VIEW relatorio.view_historico_series_anos AS
 SELECT historico_disciplinas.ref_ref_cod_aluno AS cod_aluno,
    historico_disciplinas.disciplina,
    ( SELECT s.ordenamento
           FROM pmieducar.historico_disciplinas s
          WHERE ((s.ref_ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (btrim((relatorio.get_texto_sem_caracter_especial((s.nm_disciplina)::character varying))::text) = historico_disciplinas.disciplina) AND (s.ordenamento IS NOT NULL))
          ORDER BY s.ref_sequencial DESC
         LIMIT 1) AS ordenamento,
    array_agg(historico_disciplinas.tipo_base) AS tipos_base,
    ((historico_por_disciplina.anos OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '1'::text) || '-ano'::text)))::integer AS ano_1serie,
    ((historico_por_disciplina.anos OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '2'::text) || '-ano'::text)))::integer AS ano_2serie,
    ((historico_por_disciplina.anos OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '3'::text) || '-ano'::text)))::integer AS ano_3serie,
    ((historico_por_disciplina.anos OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '4'::text) || '-ano'::text)))::integer AS ano_4serie,
    ((historico_por_disciplina.anos OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '5'::text) || '-ano'::text)))::integer AS ano_5serie,
    ((historico_por_disciplina.anos OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '6'::text) || '-ano'::text)))::integer AS ano_6serie,
    ((historico_por_disciplina.anos OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '7'::text) || '-ano'::text)))::integer AS ano_7serie,
    ((historico_por_disciplina.anos OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '8'::text) || '-ano'::text)))::integer AS ano_8serie,
    ((historico_por_disciplina.anos OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '9'::text) || '-ano'::text)))::integer AS ano_9serie,
    (historico_por_disciplina.escola OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '1'::text) || '-escola'::text)) AS escola_1serie,
    (historico_por_disciplina.escola OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '2'::text) || '-escola'::text)) AS escola_2serie,
    (historico_por_disciplina.escola OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '3'::text) || '-escola'::text)) AS escola_3serie,
    (historico_por_disciplina.escola OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '4'::text) || '-escola'::text)) AS escola_4serie,
    (historico_por_disciplina.escola OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '5'::text) || '-escola'::text)) AS escola_5serie,
    (historico_por_disciplina.escola OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '6'::text) || '-escola'::text)) AS escola_6serie,
    (historico_por_disciplina.escola OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '7'::text) || '-escola'::text)) AS escola_7serie,
    (historico_por_disciplina.escola OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '8'::text) || '-escola'::text)) AS escola_8serie,
    (historico_por_disciplina.escola OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '9'::text) || '-escola'::text)) AS escola_9serie,
    (historico_por_disciplina.escola_cidade OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '1'::text) || '-escola_cidade'::text)) AS escola_cidade_1serie,
    (historico_por_disciplina.escola_cidade OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '2'::text) || '-escola_cidade'::text)) AS escola_cidade_2serie,
    (historico_por_disciplina.escola_cidade OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '3'::text) || '-escola_cidade'::text)) AS escola_cidade_3serie,
    (historico_por_disciplina.escola_cidade OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '4'::text) || '-escola_cidade'::text)) AS escola_cidade_4serie,
    (historico_por_disciplina.escola_cidade OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '5'::text) || '-escola_cidade'::text)) AS escola_cidade_5serie,
    (historico_por_disciplina.escola_cidade OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '6'::text) || '-escola_cidade'::text)) AS escola_cidade_6serie,
    (historico_por_disciplina.escola_cidade OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '7'::text) || '-escola_cidade'::text)) AS escola_cidade_7serie,
    (historico_por_disciplina.escola_cidade OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '8'::text) || '-escola_cidade'::text)) AS escola_cidade_8serie,
    (historico_por_disciplina.escola_cidade OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '9'::text) || '-escola_cidade'::text)) AS escola_cidade_9serie,
    (historico_por_disciplina.escola_uf OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '1'::text) || '-escola_uf'::text)) AS escola_uf_1serie,
    (historico_por_disciplina.escola_uf OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '2'::text) || '-escola_uf'::text)) AS escola_uf_2serie,
    (historico_por_disciplina.escola_uf OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '3'::text) || '-escola_uf'::text)) AS escola_uf_3serie,
    (historico_por_disciplina.escola_uf OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '4'::text) || '-escola_uf'::text)) AS escola_uf_4serie,
    (historico_por_disciplina.escola_uf OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '5'::text) || '-escola_uf'::text)) AS escola_uf_5serie,
    (historico_por_disciplina.escola_uf OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '6'::text) || '-escola_uf'::text)) AS escola_uf_6serie,
    (historico_por_disciplina.escola_uf OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '7'::text) || '-escola_uf'::text)) AS escola_uf_7serie,
    (historico_por_disciplina.escola_uf OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '8'::text) || '-escola_uf'::text)) AS escola_uf_8serie,
    (historico_por_disciplina.escola_uf OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '9'::text) || '-escola_uf'::text)) AS escola_uf_9serie,
    ((historico_por_disciplina.carga_horaria OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '1'::text) || '-carga_horaria'::text)))::integer AS carga_horaria1,
    ((historico_por_disciplina.carga_horaria OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '2'::text) || '-carga_horaria'::text)))::integer AS carga_horaria2,
    ((historico_por_disciplina.carga_horaria OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '3'::text) || '-carga_horaria'::text)))::integer AS carga_horaria3,
    ((historico_por_disciplina.carga_horaria OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '4'::text) || '-carga_horaria'::text)))::integer AS carga_horaria4,
    ((historico_por_disciplina.carga_horaria OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '5'::text) || '-carga_horaria'::text)))::integer AS carga_horaria5,
    ((historico_por_disciplina.carga_horaria OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '6'::text) || '-carga_horaria'::text)))::integer AS carga_horaria6,
    ((historico_por_disciplina.carga_horaria OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '7'::text) || '-carga_horaria'::text)))::integer AS carga_horaria7,
    ((historico_por_disciplina.carga_horaria OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '8'::text) || '-carga_horaria'::text)))::integer AS carga_horaria8,
    ((historico_por_disciplina.carga_horaria OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '9'::text) || '-carga_horaria'::text)))::integer AS carga_horaria9,
    ((historico_por_disciplina.frequencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '1'::text) || '-frequencia'::text)))::numeric AS frequencia1,
    ((historico_por_disciplina.frequencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '2'::text) || '-frequencia'::text)))::numeric AS frequencia2,
    ((historico_por_disciplina.frequencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '3'::text) || '-frequencia'::text)))::numeric AS frequencia3,
    ((historico_por_disciplina.frequencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '4'::text) || '-frequencia'::text)))::numeric AS frequencia4,
    ((historico_por_disciplina.frequencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '5'::text) || '-frequencia'::text)))::numeric AS frequencia5,
    ((historico_por_disciplina.frequencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '6'::text) || '-frequencia'::text)))::numeric AS frequencia6,
    ((historico_por_disciplina.frequencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '7'::text) || '-frequencia'::text)))::numeric AS frequencia7,
    ((historico_por_disciplina.frequencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '8'::text) || '-frequencia'::text)))::numeric AS frequencia8,
    ((historico_por_disciplina.frequencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '9'::text) || '-frequencia'::text)))::numeric AS frequencia9,
    (historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '1'::text) || '-aprovado'::text)) AS status_serie1,
    (historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '2'::text) || '-aprovado'::text)) AS status_serie2,
    (historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '3'::text) || '-aprovado'::text)) AS status_serie3,
    (historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '4'::text) || '-aprovado'::text)) AS status_serie4,
    (historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '5'::text) || '-aprovado'::text)) AS status_serie5,
    (historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '6'::text) || '-aprovado'::text)) AS status_serie6,
    (historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '7'::text) || '-aprovado'::text)) AS status_serie7,
    (historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '8'::text) || '-aprovado'::text)) AS status_serie8,
    (historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '9'::text) || '-aprovado'::text)) AS status_serie9,
    ((historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '1'::text) || '-aprovado'::text)) ~~ 'Tran%'::text) AS transferido1,
    ((historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '2'::text) || '-aprovado'::text)) ~~ 'Tran%'::text) AS transferido2,
    ((historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '3'::text) || '-aprovado'::text)) ~~ 'Tran%'::text) AS transferido3,
    ((historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '4'::text) || '-aprovado'::text)) ~~ 'Tran%'::text) AS transferido4,
    ((historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '5'::text) || '-aprovado'::text)) ~~ 'Tran%'::text) AS transferido5,
    ((historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '6'::text) || '-aprovado'::text)) ~~ 'Tran%'::text) AS transferido6,
    ((historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '7'::text) || '-aprovado'::text)) ~~ 'Tran%'::text) AS transferido7,
    ((historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '8'::text) || '-aprovado'::text)) ~~ 'Tran%'::text) AS transferido8,
    ((historico_por_disciplina.aprovado OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '9'::text) || '-aprovado'::text)) ~~ 'Tran%'::text) AS transferido9,
    (historico_por_disciplina.nota OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '1'::text) || '-nota'::text)) AS nota_1serie,
    (historico_por_disciplina.nota OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '2'::text) || '-nota'::text)) AS nota_2serie,
    (historico_por_disciplina.nota OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '3'::text) || '-nota'::text)) AS nota_3serie,
    (historico_por_disciplina.nota OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '4'::text) || '-nota'::text)) AS nota_4serie,
    (historico_por_disciplina.nota OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '5'::text) || '-nota'::text)) AS nota_5serie,
    (historico_por_disciplina.nota OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '6'::text) || '-nota'::text)) AS nota_6serie,
    (historico_por_disciplina.nota OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '7'::text) || '-nota'::text)) AS nota_7serie,
    (historico_por_disciplina.nota OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '8'::text) || '-nota'::text)) AS nota_8serie,
    (historico_por_disciplina.nota OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '9'::text) || '-nota'::text)) AS nota_9serie,
    ((historico_por_disciplina.carga_horaria_disciplina OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '1'::text) || '-carga_horaria_disciplina'::text)))::integer AS carga_horaria_disciplina1,
    ((historico_por_disciplina.carga_horaria_disciplina OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '2'::text) || '-carga_horaria_disciplina'::text)))::integer AS carga_horaria_disciplina2,
    ((historico_por_disciplina.carga_horaria_disciplina OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '3'::text) || '-carga_horaria_disciplina'::text)))::integer AS carga_horaria_disciplina3,
    ((historico_por_disciplina.carga_horaria_disciplina OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '4'::text) || '-carga_horaria_disciplina'::text)))::integer AS carga_horaria_disciplina4,
    ((historico_por_disciplina.carga_horaria_disciplina OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '5'::text) || '-carga_horaria_disciplina'::text)))::integer AS carga_horaria_disciplina5,
    ((historico_por_disciplina.carga_horaria_disciplina OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '6'::text) || '-carga_horaria_disciplina'::text)))::integer AS carga_horaria_disciplina6,
    ((historico_por_disciplina.carga_horaria_disciplina OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '7'::text) || '-carga_horaria_disciplina'::text)))::integer AS carga_horaria_disciplina7,
    ((historico_por_disciplina.carga_horaria_disciplina OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '8'::text) || '-carga_horaria_disciplina'::text)))::integer AS carga_horaria_disciplina8,
    ((historico_por_disciplina.carga_horaria_disciplina OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '9'::text) || '-carga_horaria_disciplina'::text)))::integer AS carga_horaria_disciplina9,
    ((historico_por_disciplina.dependencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '1'::text) || '-dependencia'::text)))::boolean AS disciplina_dependencia1,
    ((historico_por_disciplina.dependencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '2'::text) || '-dependencia'::text)))::boolean AS disciplina_dependencia2,
    ((historico_por_disciplina.dependencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '3'::text) || '-dependencia'::text)))::boolean AS disciplina_dependencia3,
    ((historico_por_disciplina.dependencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '4'::text) || '-dependencia'::text)))::boolean AS disciplina_dependencia4,
    ((historico_por_disciplina.dependencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '5'::text) || '-dependencia'::text)))::boolean AS disciplina_dependencia5,
    ((historico_por_disciplina.dependencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '6'::text) || '-dependencia'::text)))::boolean AS disciplina_dependencia6,
    ((historico_por_disciplina.dependencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '7'::text) || '-dependencia'::text)))::boolean AS disciplina_dependencia7,
    ((historico_por_disciplina.dependencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '8'::text) || '-dependencia'::text)))::boolean AS disciplina_dependencia8,
    ((historico_por_disciplina.dependencia OPERATOR(relatorio.->) (((historico_disciplinas.disciplina || '-'::text) || '9'::text) || '-dependencia'::text)))::boolean AS disciplina_dependencia9,
    ( SELECT m.cod_matricula
           FROM pmieducar.matricula m
          WHERE ((m.ano = ( SELECT max(he.ano) AS max
                   FROM pmieducar.historico_escolar he
                  WHERE ((he.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (he.ativo = 1) AND (he.extra_curricular = 0) AND (COALESCE(he.dependencia, false) = false) AND public.isnumeric("substring"((he.nm_serie)::text, 1, 1))))) AND (m.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (m.ativo = 1) AND (m.aprovado = 4))
          ORDER BY m.cod_matricula
         LIMIT 1) AS matricula_transferido,
    ( SELECT public.textcat_all(tabl.obs) AS textcat_all
           FROM ( SELECT phe.observacao AS obs
                   FROM pmieducar.historico_escolar phe
                  WHERE ((phe.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (phe.ativo = 1) AND (phe.extra_curricular = 0) AND (COALESCE(phe.dependencia, false) = false) AND public.isnumeric("substring"((phe.nm_serie)::text, 1, 1)))
                  ORDER BY phe.ano) tabl) AS observacao_all
   FROM ((pmieducar.historico_escolar
     JOIN LATERAL ( SELECT historico_disciplinas_1.sequencial,
            historico_disciplinas_1.ref_ref_cod_aluno,
            historico_disciplinas_1.ref_sequencial,
            btrim((relatorio.get_texto_sem_caracter_especial((historico_disciplinas_1.nm_disciplina)::character varying))::text) AS disciplina,
            historico_disciplinas_1.nota,
            historico_disciplinas_1.faltas,
            historico_disciplinas_1.tipo_base
           FROM pmieducar.historico_disciplinas historico_disciplinas_1) historico_disciplinas ON (((historico_escolar.ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (historico_escolar.sequencial = historico_disciplinas.ref_sequencial))))
     JOIN LATERAL ( SELECT relatorio.hstore(array_agg(disciplina.ano_key), array_agg(disciplina.ano_value)) AS anos,
            relatorio.hstore(array_agg(disciplina.escola_key), array_agg(disciplina.escola_value)) AS escola,
            relatorio.hstore(array_agg(disciplina.escola_cidade_key), array_agg(disciplina.escola_cidade_value)) AS escola_cidade,
            relatorio.hstore(array_agg(disciplina.escola_uf_key), array_agg(disciplina.escola_uf_value)) AS escola_uf,
            relatorio.hstore(array_agg(disciplina.carga_horaria_key), array_agg(disciplina.carga_horaria_value)) AS carga_horaria,
            relatorio.hstore(array_agg(disciplina.frequencia_key), array_agg(disciplina.frequencia_value)) AS frequencia,
            relatorio.hstore(array_agg(disciplina.aprovado_key), array_agg(disciplina.aprovado_value)) AS aprovado,
            relatorio.hstore(array_agg(disciplina.nota_key), array_agg(disciplina.nota_value)) AS nota,
            relatorio.hstore(array_agg(disciplina.carga_horaria_disciplina_key), array_agg(disciplina.carga_horaria_disciplina_value)) AS carga_horaria_disciplina,
            relatorio.hstore(array_agg(disciplina.dependencia_key), array_agg(disciplina.dependencia_value)) AS dependencia,
            disciplina.disciplina,
            disciplina.ref_cod_aluno
           FROM ( SELECT (((historico_disciplinas_1.disciplina || '-'::text) ||
                        CASE
                            WHEN (historico_escolar_1.historico_grade_curso_id = 2) THEN "substring"((historico_escolar_1.nm_serie)::text, 1, 1)
                            ELSE ((("substring"((historico_escolar_1.nm_serie)::text, 1, 1))::integer + 1))::text
                        END) || '-ano'::text) AS ano_key,
                    (historico_escolar_1.ano)::text AS ano_value,
                    (((historico_disciplinas_1.disciplina || '-'::text) ||
                        CASE
                            WHEN (historico_escolar_1.historico_grade_curso_id = 2) THEN "substring"((historico_escolar_1.nm_serie)::text, 1, 1)
                            ELSE ((("substring"((historico_escolar_1.nm_serie)::text, 1, 1))::integer + 1))::text
                        END) || '-escola'::text) AS escola_key,
                    (historico_escolar_1.escola)::text AS escola_value,
                    (((historico_disciplinas_1.disciplina || '-'::text) ||
                        CASE
                            WHEN (historico_escolar_1.historico_grade_curso_id = 2) THEN "substring"((historico_escolar_1.nm_serie)::text, 1, 1)
                            ELSE ((("substring"((historico_escolar_1.nm_serie)::text, 1, 1))::integer + 1))::text
                        END) || '-escola_cidade'::text) AS escola_cidade_key,
                    (historico_escolar_1.escola_cidade)::text AS escola_cidade_value,
                    (((historico_disciplinas_1.disciplina || '-'::text) ||
                        CASE
                            WHEN (historico_escolar_1.historico_grade_curso_id = 2) THEN "substring"((historico_escolar_1.nm_serie)::text, 1, 1)
                            ELSE ((("substring"((historico_escolar_1.nm_serie)::text, 1, 1))::integer + 1))::text
                        END) || '-escola_uf'::text) AS escola_uf_key,
                    (historico_escolar_1.escola_uf)::text AS escola_uf_value,
                    (((historico_disciplinas_1.disciplina || '-'::text) ||
                        CASE
                            WHEN (historico_escolar_1.historico_grade_curso_id = 2) THEN "substring"((historico_escolar_1.nm_serie)::text, 1, 1)
                            ELSE ((("substring"((historico_escolar_1.nm_serie)::text, 1, 1))::integer + 1))::text
                        END) || '-carga_horaria'::text) AS carga_horaria_key,
                    (historico_escolar_1.carga_horaria)::text AS carga_horaria_value,
                    (((historico_disciplinas_1.disciplina || '-'::text) ||
                        CASE
                            WHEN (historico_escolar_1.historico_grade_curso_id = 2) THEN "substring"((historico_escolar_1.nm_serie)::text, 1, 1)
                            ELSE ((("substring"((historico_escolar_1.nm_serie)::text, 1, 1))::integer + 1))::text
                        END) || '-frequencia'::text) AS frequencia_key,
                    (historico_escolar_1.frequencia)::text AS frequencia_value,
                    (((historico_disciplinas_1.disciplina || '-'::text) ||
                        CASE
                            WHEN (historico_escolar_1.historico_grade_curso_id = 2) THEN "substring"((historico_escolar_1.nm_serie)::text, 1, 1)
                            ELSE ((("substring"((historico_escolar_1.nm_serie)::text, 1, 1))::integer + 1))::text
                        END) || '-aprovado'::text) AS aprovado_key,
                    (
                        CASE (historico_escolar_1.aprovado)::text
                            WHEN '1'::text THEN 'Apro'::text
                            WHEN '12'::text THEN 'AprDep'::text
                            WHEN '13'::text THEN 'AprCo'::text
                            WHEN '2'::text THEN 'Repr'::text
                            WHEN '3'::text THEN 'Curs'::text
                            WHEN '4'::text THEN 'Tran'::text
                            WHEN '5'::text THEN 'Recl'::text
                            WHEN '6'::text THEN 'Aban'::text
                            WHEN '14'::text THEN 'RpFt'::text
                            WHEN '15'::text THEN 'Fal'::text
                            ELSE ''::text
                        END ||
                        CASE
                            WHEN (historico_escolar_1.aceleracao = 1) THEN ' AC'::text
                            ELSE ''::text
                        END) AS aprovado_value,
                    (((historico_disciplinas_1.disciplina || '-'::text) ||
                        CASE
                            WHEN (historico_escolar_1.historico_grade_curso_id = 2) THEN "substring"((historico_escolar_1.nm_serie)::text, 1, 1)
                            ELSE ((("substring"((historico_escolar_1.nm_serie)::text, 1, 1))::integer + 1))::text
                        END) || '-nota'::text) AS nota_key,
                        CASE
                            WHEN ((public.isnumeric(btrim((historico_disciplinas_1.nota)::text)) = true) AND (("substring"(btrim((historico_disciplinas_1.nota)::text), 1, 1))::integer >= 0) AND (("substring"(btrim((historico_disciplinas_1.nota)::text), 1, 1))::integer <= 9)) THEN replace((historico_disciplinas_1.nota)::text, '.'::text, ','::text)
                            ELSE btrim((historico_disciplinas_1.nota)::text)
                        END AS nota_value,
                    (((historico_disciplinas_1.disciplina || '-'::text) ||
                        CASE
                            WHEN (historico_escolar_1.historico_grade_curso_id = 2) THEN "substring"((historico_escolar_1.nm_serie)::text, 1, 1)
                            ELSE ((("substring"((historico_escolar_1.nm_serie)::text, 1, 1))::integer + 1))::text
                        END) || '-carga_horaria_disciplina'::text) AS carga_horaria_disciplina_key,
                    (historico_disciplinas_1.carga_horaria_disciplina)::text AS carga_horaria_disciplina_value,
                    (((historico_disciplinas_1.disciplina || '-'::text) ||
                        CASE
                            WHEN (historico_escolar_1.historico_grade_curso_id = 2) THEN "substring"((historico_escolar_1.nm_serie)::text, 1, 1)
                            ELSE ((("substring"((historico_escolar_1.nm_serie)::text, 1, 1))::integer + 1))::text
                        END) || '-dependencia'::text) AS dependencia_key,
                    (historico_disciplinas_1.dependencia)::text AS dependencia_value,
                    historico_disciplinas_1.disciplina,
                    historico_escolar_1.ref_cod_aluno
                   FROM (pmieducar.historico_escolar historico_escolar_1
                     JOIN LATERAL ( SELECT historico_disciplinas_2.sequencial,
                            historico_disciplinas_2.ref_ref_cod_aluno,
                            historico_disciplinas_2.ref_sequencial,
                            btrim((relatorio.get_texto_sem_caracter_especial((historico_disciplinas_2.nm_disciplina)::character varying))::text) AS disciplina,
                            historico_disciplinas_2.nota,
                            historico_disciplinas_2.faltas,
                            historico_disciplinas_2.carga_horaria_disciplina,
                            historico_disciplinas_2.dependencia
                           FROM pmieducar.historico_disciplinas historico_disciplinas_2) historico_disciplinas_1 ON (((historico_escolar_1.ref_cod_aluno = historico_disciplinas_1.ref_ref_cod_aluno) AND (historico_escolar_1.sequencial = historico_disciplinas_1.ref_sequencial))))
                  WHERE ((historico_escolar_1.extra_curricular = 0) AND (historico_escolar_1.ativo = 1) AND (COALESCE(historico_escolar_1.dependencia, false) = false) AND public.isnumeric("substring"((historico_escolar_1.nm_serie)::text, 1, 1)) AND (historico_disciplinas_1.ref_ref_cod_aluno = historico_disciplinas_1.ref_ref_cod_aluno) AND (historico_escolar_1.sequencial = ( SELECT hee.sequencial
                           FROM pmieducar.historico_escolar hee
                          WHERE (("substring"((hee.nm_serie)::text, 1, 1) = "substring"((historico_escolar_1.nm_serie)::text, 1, 1)) AND (hee.ref_cod_aluno = historico_escolar_1.ref_cod_aluno) AND (hee.extra_curricular = 0) AND (COALESCE(hee.dependencia, false) = false) AND public.isnumeric("substring"((hee.nm_serie)::text, 1, 1)) AND (hee.ativo = 1))
                          ORDER BY hee.ano DESC, (relatorio.prioridade_historico((hee.aprovado)::numeric))
                         LIMIT 1)))
                  GROUP BY historico_disciplinas_1.disciplina, historico_escolar_1.ano, historico_escolar_1.escola, historico_escolar_1.escola_cidade, historico_escolar_1.escola_uf, historico_escolar_1.carga_horaria, historico_escolar_1.frequencia, historico_escolar_1.aprovado, historico_escolar_1.nm_serie, historico_escolar_1.aceleracao, historico_escolar_1.historico_grade_curso_id, historico_disciplinas_1.nota, historico_disciplinas_1.carga_horaria_disciplina, historico_disciplinas_1.dependencia, historico_escolar_1.ref_cod_aluno
                  ORDER BY historico_escolar_1.ano DESC, (relatorio.prioridade_historico((historico_escolar_1.aprovado)::numeric))) disciplina
          GROUP BY disciplina.disciplina, disciplina.ref_cod_aluno) historico_por_disciplina ON (((historico_por_disciplina.ref_cod_aluno = historico_escolar.ref_cod_aluno) AND (historico_por_disciplina.disciplina = historico_disciplinas.disciplina))))
  WHERE ((historico_escolar.extra_curricular = 0) AND (COALESCE(historico_escolar.dependencia, false) = false) AND public.isnumeric("substring"((historico_escolar.nm_serie)::text, 1, 1)) AND (historico_escolar.ativo = 1))
  GROUP BY historico_disciplinas.disciplina, historico_disciplinas.ref_ref_cod_aluno, historico_por_disciplina.anos, historico_por_disciplina.escola, historico_por_disciplina.escola_cidade, historico_por_disciplina.escola_uf, historico_por_disciplina.carga_horaria, historico_por_disciplina.frequencia, historico_por_disciplina.aprovado, historico_por_disciplina.nota, historico_por_disciplina.carga_horaria_disciplina, historico_por_disciplina.dependencia
  ORDER BY ( SELECT s.ordenamento
           FROM pmieducar.historico_disciplinas s
          WHERE ((s.ref_ref_cod_aluno = historico_disciplinas.ref_ref_cod_aluno) AND (btrim((relatorio.get_texto_sem_caracter_especial((s.nm_disciplina)::character varying))::text) = historico_disciplinas.disciplina) AND (s.ordenamento IS NOT NULL))
          ORDER BY s.ref_sequencial DESC
         LIMIT 1), historico_disciplinas.disciplina;


--
-- Name: view_modulo; Type: VIEW; Schema: relatorio; Owner: -
--

CREATE VIEW relatorio.view_modulo AS
 SELECT DISTINCT turma.cod_turma,
    modulo_curso.cod_modulo AS cod_modulo_curso,
    modulo_turma.cod_modulo AS cod_modulo_turma,
        CASE
            WHEN ((curso.padrao_ano_escolar = 0) AND (modulo_turma.cod_modulo IS NOT NULL)) THEN modulo_turma.nm_tipo
            ELSE modulo_curso.nm_tipo
        END AS nome,
        CASE
            WHEN ((curso.padrao_ano_escolar = 0) AND (modulo_turma.cod_modulo IS NOT NULL)) THEN turma_modulo.sequencial
            ELSE (ano_letivo_modulo.sequencial)::integer
        END AS sequencial
   FROM (((((pmieducar.turma
     JOIN pmieducar.curso ON ((curso.cod_curso = turma.ref_cod_curso)))
     LEFT JOIN pmieducar.ano_letivo_modulo ON (((ano_letivo_modulo.ref_ano = turma.ano) AND (ano_letivo_modulo.ref_ref_cod_escola = turma.ref_ref_cod_escola))))
     LEFT JOIN pmieducar.turma_modulo ON ((turma_modulo.ref_cod_turma = turma.cod_turma)))
     LEFT JOIN pmieducar.modulo modulo_curso ON ((modulo_curso.cod_modulo = ano_letivo_modulo.ref_cod_modulo)))
     LEFT JOIN pmieducar.modulo modulo_turma ON ((modulo_turma.cod_modulo = turma_modulo.ref_cod_modulo)))
  ORDER BY turma.cod_turma, modulo_curso.cod_modulo, modulo_turma.cod_modulo,
        CASE
            WHEN ((curso.padrao_ano_escolar = 0) AND (modulo_turma.cod_modulo IS NOT NULL)) THEN modulo_turma.nm_tipo
            ELSE modulo_curso.nm_tipo
        END,
        CASE
            WHEN ((curso.padrao_ano_escolar = 0) AND (modulo_turma.cod_modulo IS NOT NULL)) THEN turma_modulo.sequencial
            ELSE (ano_letivo_modulo.sequencial)::integer
        END;


--
-- Name: view_situacao_relatorios; Type: VIEW; Schema: relatorio; Owner: -
--

CREATE VIEW relatorio.view_situacao_relatorios AS
 SELECT matricula.cod_matricula,
    situacao_matricula.cod_situacao,
    matricula_turma.ref_cod_turma AS cod_turma,
    matricula_turma.sequencial,
        CASE
            WHEN matricula_turma.remanejado THEN 'Remanejado'::character varying
            WHEN matricula_turma.transferido THEN 'Transferido'::character varying
            WHEN matricula_turma.reclassificado THEN 'Reclassificado'::character varying
            WHEN matricula_turma.abandono THEN 'Deixou de Frequentar'::character varying
            WHEN (matricula.aprovado = 1) THEN 'Aprovado'::character varying
            WHEN (matricula.aprovado = 12) THEN 'Ap. Depen.'::character varying
            WHEN (matricula.aprovado = 13) THEN 'Ap. Cons.'::character varying
            WHEN (matricula.aprovado = 2) THEN 'Reprovado'::character varying
            WHEN (matricula.aprovado = 3) THEN 'Cursando'::character varying
            WHEN (matricula.aprovado = 4) THEN 'Transferido'::character varying
            WHEN (matricula.aprovado = 5) THEN 'Reclassificado'::character varying
            WHEN (matricula.aprovado = 6) THEN 'Deixou de Frequentar'::character varying
            WHEN (matricula.aprovado = 14) THEN 'Rp. Faltas'::character varying
            WHEN (matricula.aprovado = 15) THEN 'Falecido'::character varying
            ELSE 'Recl'::character varying
        END AS texto_situacao,
        CASE
            WHEN matricula_turma.remanejado THEN 'Rem'::character varying
            WHEN matricula_turma.transferido THEN 'Trs'::character varying
            WHEN matricula_turma.reclassificado THEN 'Recl'::character varying
            WHEN matricula_turma.abandono THEN 'DeFr'::character varying
            WHEN (matricula.aprovado = 1) THEN 'Apr'::character varying
            WHEN (matricula.aprovado = 12) THEN 'ApDp'::character varying
            WHEN (matricula.aprovado = 13) THEN 'ApCo'::character varying
            WHEN (matricula.aprovado = 2) THEN 'Rep'::character varying
            WHEN (matricula.aprovado = 3) THEN 'Cur'::character varying
            WHEN (matricula.aprovado = 4) THEN 'Trs'::character varying
            WHEN (matricula.aprovado = 5) THEN 'Recl'::character varying
            WHEN (matricula.aprovado = 6) THEN 'DeFr'::character varying
            WHEN (matricula.aprovado = 14) THEN 'RpFt'::character varying
            WHEN (matricula.aprovado = 15) THEN 'Fal'::character varying
            ELSE 'Recl'::character varying
        END AS texto_situacao_simplificado
   FROM relatorio.situacao_matricula,
    (((pmieducar.matricula
     JOIN pmieducar.escola ON ((escola.cod_escola = matricula.ref_ref_cod_escola)))
     JOIN pmieducar.instituicao ON ((instituicao.cod_instituicao = escola.ref_cod_instituicao)))
     LEFT JOIN pmieducar.matricula_turma ON ((matricula_turma.ref_cod_matricula = matricula.cod_matricula)))
  WHERE (true AND (matricula.ativo = 1) AND
        CASE
            WHEN (instituicao.data_base_remanejamento IS NULL) THEN (COALESCE(matricula_turma.remanejado, false) = false)
            ELSE true
        END AND
        CASE
            WHEN (matricula.aprovado = 4) THEN ((matricula_turma.ativo = 1) OR matricula_turma.transferido OR matricula_turma.reclassificado OR matricula_turma.remanejado OR (matricula_turma.sequencial = ( SELECT max(mt.sequencial) AS max
               FROM pmieducar.matricula_turma mt
              WHERE (mt.ref_cod_matricula = matricula.cod_matricula))))
            WHEN (matricula.aprovado = 6) THEN ((matricula_turma.ativo = 1) OR matricula_turma.abandono OR ((matricula_turma.transferido OR matricula_turma.reclassificado OR matricula_turma.remanejado) AND (matricula_turma.sequencial < ( SELECT max(mt.sequencial) AS max
               FROM pmieducar.matricula_turma mt
              WHERE (mt.ref_cod_matricula = matricula.cod_matricula)))))
            WHEN (matricula.aprovado = 15) THEN ((matricula_turma.ativo = 1) OR matricula_turma.falecido)
            ELSE ((matricula_turma.ativo = 1) OR matricula_turma.transferido OR matricula_turma.reclassificado OR matricula_turma.abandono OR matricula_turma.remanejado OR (matricula_turma.falecido AND (matricula_turma.sequencial < ( SELECT max(mt.sequencial) AS max
               FROM pmieducar.matricula_turma mt
              WHERE (mt.ref_cod_matricula = matricula.cod_matricula)))))
        END AND
        CASE
            WHEN (situacao_matricula.cod_situacao = 10) THEN (matricula.aprovado = ANY (ARRAY[1, 2, 3, 4, 5, 6, 12, 13, 14, 15]))
            WHEN (situacao_matricula.cod_situacao = 9) THEN ((matricula.aprovado = ANY (ARRAY[1, 2, 3, 5, 12, 13, 14])) AND ((NOT matricula_turma.reclassificado) OR (matricula_turma.reclassificado IS NULL)) AND ((NOT matricula_turma.abandono) OR (matricula_turma.abandono IS NULL)) AND ((NOT matricula_turma.remanejado) OR (matricula_turma.remanejado IS NULL)) AND ((NOT matricula_turma.transferido) OR (matricula_turma.transferido IS NULL)) AND ((NOT matricula_turma.falecido) OR (matricula_turma.falecido IS NULL)))
            WHEN (situacao_matricula.cod_situacao = 2) THEN ((matricula.aprovado = ANY (ARRAY[2, 14])) AND ((NOT matricula_turma.reclassificado) OR (matricula_turma.reclassificado IS NULL)) AND ((NOT matricula_turma.abandono) OR (matricula_turma.abandono IS NULL)) AND ((NOT matricula_turma.remanejado) OR (matricula_turma.remanejado IS NULL)) AND ((NOT matricula_turma.transferido) OR (matricula_turma.transferido IS NULL)) AND ((NOT matricula_turma.falecido) OR (matricula_turma.falecido IS NULL)))
            WHEN (situacao_matricula.cod_situacao = 1) THEN ((matricula.aprovado = ANY (ARRAY[1, 12, 13])) AND ((NOT matricula_turma.reclassificado) OR (matricula_turma.reclassificado IS NULL)) AND ((NOT matricula_turma.abandono) OR (matricula_turma.abandono IS NULL)) AND ((NOT matricula_turma.remanejado) OR (matricula_turma.remanejado IS NULL)) AND ((NOT matricula_turma.transferido) OR (matricula_turma.transferido IS NULL)) AND ((NOT matricula_turma.falecido) OR (matricula_turma.falecido IS NULL)))
            WHEN (situacao_matricula.cod_situacao = ANY (ARRAY[3, 12, 13])) THEN ((matricula.aprovado = situacao_matricula.cod_situacao) AND ((NOT matricula_turma.reclassificado) OR (matricula_turma.reclassificado IS NULL)) AND ((NOT matricula_turma.abandono) OR (matricula_turma.abandono IS NULL)) AND ((NOT matricula_turma.remanejado) OR (matricula_turma.remanejado IS NULL)) AND ((NOT matricula_turma.transferido) OR (matricula_turma.transferido IS NULL)) AND ((NOT matricula_turma.falecido) OR (matricula_turma.falecido IS NULL)))
            ELSE (matricula.aprovado = situacao_matricula.cod_situacao)
        END);


--
-- Name: view_situacao; Type: VIEW; Schema: relatorio; Owner: -
--

CREATE VIEW relatorio.view_situacao AS
 SELECT cod_matricula,
    cod_situacao,
    cod_turma,
    sequencial,
    texto_situacao,
    texto_situacao_simplificado
   FROM relatorio.view_situacao_relatorios
  WHERE (sequencial = ( SELECT max(mt.sequencial) AS max
           FROM pmieducar.matricula_turma mt
          WHERE ((mt.ref_cod_turma = view_situacao_relatorios.cod_turma) AND (mt.ref_cod_matricula = view_situacao_relatorios.cod_matricula))));


--
-- Name: codigo_cartorio_inep id; Type: DEFAULT; Schema: cadastro; Owner: -
--

ALTER TABLE ONLY cadastro.codigo_cartorio_inep ALTER COLUMN id SET DEFAULT nextval('cadastro.codigo_cartorio_inep_id_seq'::regclass);


--
-- Name: area_conhecimento id; Type: DEFAULT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.area_conhecimento ALTER COLUMN id SET DEFAULT nextval('modules.area_conhecimento_id_seq'::regclass);


--
-- Name: componente_curricular id; Type: DEFAULT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.componente_curricular ALTER COLUMN id SET DEFAULT nextval('modules.componente_curricular_id_seq'::regclass);


--
-- Name: componente_curricular_ano_escolar_excluidos id; Type: DEFAULT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.componente_curricular_ano_escolar_excluidos ALTER COLUMN id SET DEFAULT nextval('modules.componente_curricular_ano_escolar_excluidos_id_seq'::regclass);


--
-- Name: config_movimento_geral id; Type: DEFAULT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.config_movimento_geral ALTER COLUMN id SET DEFAULT nextval('modules.config_movimento_geral_id_seq'::regclass);


--
-- Name: educacenso_cod_aluno id; Type: DEFAULT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.educacenso_cod_aluno ALTER COLUMN id SET DEFAULT nextval('modules.educacenso_cod_aluno_id_seq'::regclass);


--
-- Name: educacenso_cod_docente id; Type: DEFAULT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.educacenso_cod_docente ALTER COLUMN id SET DEFAULT nextval('modules.educacenso_cod_docente_id_seq'::regclass);


--
-- Name: educacenso_cod_escola id; Type: DEFAULT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.educacenso_cod_escola ALTER COLUMN id SET DEFAULT nextval('modules.educacenso_cod_escola_id_seq'::regclass);


--
-- Name: educacenso_cod_turma id; Type: DEFAULT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.educacenso_cod_turma ALTER COLUMN id SET DEFAULT nextval('modules.educacenso_cod_turma_id_seq'::regclass);


--
-- Name: educacenso_curso_superior id; Type: DEFAULT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.educacenso_curso_superior ALTER COLUMN id SET DEFAULT nextval('modules.educacenso_curso_superior_id_seq'::regclass);


--
-- Name: educacenso_ies id; Type: DEFAULT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.educacenso_ies ALTER COLUMN id SET DEFAULT nextval('modules.educacenso_ies_id_seq'::regclass);


--
-- Name: educacenso_matricula id; Type: DEFAULT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.educacenso_matricula ALTER COLUMN id SET DEFAULT nextval('modules.educacenso_matricula_id_seq'::regclass);


--
-- Name: falta_aluno id; Type: DEFAULT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.falta_aluno ALTER COLUMN id SET DEFAULT nextval('modules.falta_aluno_id_seq'::regclass);


--
-- Name: falta_componente_curricular id; Type: DEFAULT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.falta_componente_curricular ALTER COLUMN id SET DEFAULT nextval('modules.falta_componente_curricular_id_seq'::regclass);


--
-- Name: falta_geral id; Type: DEFAULT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.falta_geral ALTER COLUMN id SET DEFAULT nextval('modules.falta_geral_id_seq'::regclass);


--
-- Name: formula_media id; Type: DEFAULT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.formula_media ALTER COLUMN id SET DEFAULT nextval('modules.formula_media_id_seq'::regclass);


--
-- Name: nota_aluno id; Type: DEFAULT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.nota_aluno ALTER COLUMN id SET DEFAULT nextval('modules.nota_aluno_id_seq'::regclass);


--
-- Name: nota_componente_curricular id; Type: DEFAULT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.nota_componente_curricular ALTER COLUMN id SET DEFAULT nextval('modules.nota_componente_curricular_id_seq'::regclass);


--
-- Name: parecer_aluno id; Type: DEFAULT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.parecer_aluno ALTER COLUMN id SET DEFAULT nextval('modules.parecer_aluno_id_seq'::regclass);


--
-- Name: parecer_componente_curricular id; Type: DEFAULT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.parecer_componente_curricular ALTER COLUMN id SET DEFAULT nextval('modules.parecer_componente_curricular_id_seq'::regclass);


--
-- Name: parecer_geral id; Type: DEFAULT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.parecer_geral ALTER COLUMN id SET DEFAULT nextval('modules.parecer_geral_id_seq'::regclass);


--
-- Name: povo_indigena_educacenso id; Type: DEFAULT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.povo_indigena_educacenso ALTER COLUMN id SET DEFAULT nextval('modules.povo_indigena_educacenso_id_seq'::regclass);


--
-- Name: regra_avaliacao id; Type: DEFAULT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.regra_avaliacao ALTER COLUMN id SET DEFAULT nextval('modules.regra_avaliacao_id_seq'::regclass);


--
-- Name: regra_avaliacao_serie_ano_excluidos id; Type: DEFAULT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.regra_avaliacao_serie_ano_excluidos ALTER COLUMN id SET DEFAULT nextval('modules.regra_avaliacao_serie_ano_excluidos_id_seq'::regclass);


--
-- Name: tabela_arredondamento id; Type: DEFAULT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.tabela_arredondamento ALTER COLUMN id SET DEFAULT nextval('modules.tabela_arredondamento_id_seq'::regclass);


--
-- Name: tabela_arredondamento_valor id; Type: DEFAULT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.tabela_arredondamento_valor ALTER COLUMN id SET DEFAULT nextval('modules.tabela_arredondamento_valor_id_seq'::regclass);


--
-- Name: aluno_aluno_beneficio id; Type: DEFAULT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.aluno_aluno_beneficio ALTER COLUMN id SET DEFAULT nextval('pmieducar.aluno_aluno_beneficio_id_seq'::regclass);


--
-- Name: aluno_historico_altura_peso id; Type: DEFAULT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.aluno_historico_altura_peso ALTER COLUMN id SET DEFAULT nextval('pmieducar.aluno_historico_altura_peso_id_seq'::regclass);


--
-- Name: ano_letivo_modulo id; Type: DEFAULT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.ano_letivo_modulo ALTER COLUMN id SET DEFAULT nextval('pmieducar.ano_letivo_modulo_id_seq'::regclass);


--
-- Name: backup id; Type: DEFAULT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.backup ALTER COLUMN id SET DEFAULT nextval('pmieducar.backup_id_seq'::regclass);


--
-- Name: busca_ativa id; Type: DEFAULT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.busca_ativa ALTER COLUMN id SET DEFAULT nextval('pmieducar.busca_ativa_id_seq'::regclass);


--
-- Name: calendario_dia id; Type: DEFAULT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.calendario_dia ALTER COLUMN id SET DEFAULT nextval('pmieducar.calendario_dia_id_seq'::regclass);


--
-- Name: escola_ano_letivo id; Type: DEFAULT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.escola_ano_letivo ALTER COLUMN id SET DEFAULT nextval('pmieducar.escola_ano_letivo_id_seq'::regclass);


--
-- Name: escola_serie_disciplina id; Type: DEFAULT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.escola_serie_disciplina ALTER COLUMN id SET DEFAULT nextval('pmieducar.escola_serie_disciplina_id_seq'::regclass);


--
-- Name: escola_serie_disciplina_excluidos id; Type: DEFAULT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.escola_serie_disciplina_excluidos ALTER COLUMN id SET DEFAULT nextval('pmieducar.escola_serie_disciplina_excluidos_id_seq'::regclass);


--
-- Name: escola_usuario id; Type: DEFAULT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.escola_usuario ALTER COLUMN id SET DEFAULT nextval('pmieducar.escola_usuario_id_seq'::regclass);


--
-- Name: historico_disciplinas id; Type: DEFAULT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.historico_disciplinas ALTER COLUMN id SET DEFAULT nextval('pmieducar.historico_disciplinas_id_seq'::regclass);


--
-- Name: historico_escolar id; Type: DEFAULT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.historico_escolar ALTER COLUMN id SET DEFAULT nextval('pmieducar.historico_escolar_id_seq'::regclass);


--
-- Name: matricula_turma id; Type: DEFAULT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.matricula_turma ALTER COLUMN id SET DEFAULT nextval('pmieducar.matricula_turma_id_seq'::regclass);


--
-- Name: matricula_turma_excluidos id; Type: DEFAULT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.matricula_turma_excluidos ALTER COLUMN id SET DEFAULT nextval('pmieducar.matricula_turma_excluidos_id_seq'::regclass);


--
-- Name: projeto_aluno id; Type: DEFAULT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.projeto_aluno ALTER COLUMN id SET DEFAULT nextval('pmieducar.projeto_aluno_id_seq'::regclass);


--
-- Name: sequencia_serie id; Type: DEFAULT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.sequencia_serie ALTER COLUMN id SET DEFAULT nextval('pmieducar.sequencia_serie_id_seq'::regclass);


--
-- Name: servidor_afastamento id; Type: DEFAULT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.servidor_afastamento ALTER COLUMN id SET DEFAULT nextval('pmieducar.servidor_afastamento_id_seq'::regclass);


--
-- Name: servidor_frequencia id; Type: DEFAULT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.servidor_frequencia ALTER COLUMN id SET DEFAULT nextval('pmieducar.servidor_frequencia_id_seq'::regclass);


--
-- Name: turma_serie id; Type: DEFAULT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.turma_serie ALTER COLUMN id SET DEFAULT nextval('pmieducar.turma_serie_id_seq'::regclass);


--
-- Name: cities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cities ALTER COLUMN id SET DEFAULT nextval('public.cities_id_seq'::regclass);


--
-- Name: countries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.countries ALTER COLUMN id SET DEFAULT nextval('public.countries_id_seq'::regclass);


--
-- Name: districts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.districts ALTER COLUMN id SET DEFAULT nextval('public.districts_id_seq'::regclass);


--
-- Name: educacenso_imports id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.educacenso_imports ALTER COLUMN id SET DEFAULT nextval('public.educacenso_imports_id_seq'::regclass);


--
-- Name: employee_graduation_disciplines id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_graduation_disciplines ALTER COLUMN id SET DEFAULT nextval('public.employee_graduation_disciplines_id_seq'::regclass);


--
-- Name: employee_graduations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_graduations ALTER COLUMN id SET DEFAULT nextval('public.employee_graduations_id_seq'::regclass);


--
-- Name: ieducar_audit id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ieducar_audit ALTER COLUMN id SET DEFAULT nextval('public.ieducar_audit_id_seq'::regclass);


--
-- Name: log_unification_old_data id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.log_unification_old_data ALTER COLUMN id SET DEFAULT nextval('public.log_unification_old_data_id_seq'::regclass);


--
-- Name: log_unifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.log_unifications ALTER COLUMN id SET DEFAULT nextval('public.log_unifications_id_seq'::regclass);


--
-- Name: manager_access_criterias id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manager_access_criterias ALTER COLUMN id SET DEFAULT nextval('public.manager_access_criterias_id_seq'::regclass);


--
-- Name: manager_link_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manager_link_types ALTER COLUMN id SET DEFAULT nextval('public.manager_link_types_id_seq'::regclass);


--
-- Name: manager_roles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manager_roles ALTER COLUMN id SET DEFAULT nextval('public.manager_roles_id_seq'::regclass);


--
-- Name: menus id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menus ALTER COLUMN id SET DEFAULT nextval('public.menus_id_seq'::regclass);


--
-- Name: migrations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.migrations ALTER COLUMN id SET DEFAULT nextval('public.migrations_id_seq'::regclass);


--
-- Name: personal_access_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personal_access_tokens ALTER COLUMN id SET DEFAULT nextval('public.personal_access_tokens_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: deficiencia_excluidos deficiencia_excluidos_pkey; Type: CONSTRAINT; Schema: cadastro; Owner: -
--

ALTER TABLE ONLY cadastro.deficiencia_excluidos
    ADD CONSTRAINT deficiencia_excluidos_pkey PRIMARY KEY (cod_deficiencia);


--
-- Name: fisica_foto fisica_foto_pkey; Type: CONSTRAINT; Schema: cadastro; Owner: -
--

ALTER TABLE ONLY cadastro.fisica_foto
    ADD CONSTRAINT fisica_foto_pkey PRIMARY KEY (idpes);


--
-- Name: deficiencia pk_cadastro_escolaridade; Type: CONSTRAINT; Schema: cadastro; Owner: -
--

ALTER TABLE ONLY cadastro.deficiencia
    ADD CONSTRAINT pk_cadastro_escolaridade PRIMARY KEY (cod_deficiencia);


--
-- Name: documento pk_documento; Type: CONSTRAINT; Schema: cadastro; Owner: -
--

ALTER TABLE ONLY cadastro.documento
    ADD CONSTRAINT pk_documento PRIMARY KEY (idpes);


--
-- Name: escolaridade pk_escolaridade; Type: CONSTRAINT; Schema: cadastro; Owner: -
--

ALTER TABLE ONLY cadastro.escolaridade
    ADD CONSTRAINT pk_escolaridade PRIMARY KEY (idesco);


--
-- Name: estado_civil pk_estado_civil; Type: CONSTRAINT; Schema: cadastro; Owner: -
--

ALTER TABLE ONLY cadastro.estado_civil
    ADD CONSTRAINT pk_estado_civil PRIMARY KEY (ideciv);


--
-- Name: fisica pk_fisica; Type: CONSTRAINT; Schema: cadastro; Owner: -
--

ALTER TABLE ONLY cadastro.fisica
    ADD CONSTRAINT pk_fisica PRIMARY KEY (idpes);


--
-- Name: fisica_deficiencia pk_fisica_deficiencia; Type: CONSTRAINT; Schema: cadastro; Owner: -
--

ALTER TABLE ONLY cadastro.fisica_deficiencia
    ADD CONSTRAINT pk_fisica_deficiencia PRIMARY KEY (ref_idpes, ref_cod_deficiencia);


--
-- Name: fisica_raca pk_fisica_raca; Type: CONSTRAINT; Schema: cadastro; Owner: -
--

ALTER TABLE ONLY cadastro.fisica_raca
    ADD CONSTRAINT pk_fisica_raca PRIMARY KEY (ref_idpes);


--
-- Name: fone_pessoa pk_fone_pessoa; Type: CONSTRAINT; Schema: cadastro; Owner: -
--

ALTER TABLE ONLY cadastro.fone_pessoa
    ADD CONSTRAINT pk_fone_pessoa PRIMARY KEY (idpes, tipo);


--
-- Name: codigo_cartorio_inep pk_id; Type: CONSTRAINT; Schema: cadastro; Owner: -
--

ALTER TABLE ONLY cadastro.codigo_cartorio_inep
    ADD CONSTRAINT pk_id PRIMARY KEY (id);


--
-- Name: juridica pk_juridica; Type: CONSTRAINT; Schema: cadastro; Owner: -
--

ALTER TABLE ONLY cadastro.juridica
    ADD CONSTRAINT pk_juridica PRIMARY KEY (idpes);


--
-- Name: orgao_emissor_rg pk_orgao_emissor_rg; Type: CONSTRAINT; Schema: cadastro; Owner: -
--

ALTER TABLE ONLY cadastro.orgao_emissor_rg
    ADD CONSTRAINT pk_orgao_emissor_rg PRIMARY KEY (idorg_rg);


--
-- Name: pessoa pk_pessoa; Type: CONSTRAINT; Schema: cadastro; Owner: -
--

ALTER TABLE ONLY cadastro.pessoa
    ADD CONSTRAINT pk_pessoa PRIMARY KEY (idpes);


--
-- Name: raca raca_pkey; Type: CONSTRAINT; Schema: cadastro; Owner: -
--

ALTER TABLE ONLY cadastro.raca
    ADD CONSTRAINT raca_pkey PRIMARY KEY (cod_raca);


--
-- Name: area_conhecimento area_conhecimento_pkey; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.area_conhecimento
    ADD CONSTRAINT area_conhecimento_pkey PRIMARY KEY (id, instituicao_id);


--
-- Name: calendario_turma calendario_turma_pk; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.calendario_turma
    ADD CONSTRAINT calendario_turma_pk PRIMARY KEY (calendario_ano_letivo_id, ano, mes, dia, turma_id);


--
-- Name: config_movimento_geral cod_config_movimento_geral_pkey; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.config_movimento_geral
    ADD CONSTRAINT cod_config_movimento_geral_pkey PRIMARY KEY (id);


--
-- Name: componente_curricular_ano_escolar_excluidos componente_curricular_ano_escolar_excluidos_pkey; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.componente_curricular_ano_escolar_excluidos
    ADD CONSTRAINT componente_curricular_ano_escolar_excluidos_pkey PRIMARY KEY (id);


--
-- Name: componente_curricular_ano_escolar componente_curricular_ano_escolar_pkey; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.componente_curricular_ano_escolar
    ADD CONSTRAINT componente_curricular_ano_escolar_pkey PRIMARY KEY (componente_curricular_id, ano_escolar_id);


--
-- Name: componente_curricular componente_curricular_pkey; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.componente_curricular
    ADD CONSTRAINT componente_curricular_pkey PRIMARY KEY (id);


--
-- Name: componente_curricular_turma componente_curricular_turma_pkey; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.componente_curricular_turma
    ADD CONSTRAINT componente_curricular_turma_pkey PRIMARY KEY (componente_curricular_id, turma_id);


--
-- Name: educacenso_cod_aluno educacenso_cod_aluno_pkey; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.educacenso_cod_aluno
    ADD CONSTRAINT educacenso_cod_aluno_pkey PRIMARY KEY (id);


--
-- Name: educacenso_cod_docente educacenso_cod_docente_pkey; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.educacenso_cod_docente
    ADD CONSTRAINT educacenso_cod_docente_pkey PRIMARY KEY (id);


--
-- Name: educacenso_cod_escola educacenso_cod_escola_pkey; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.educacenso_cod_escola
    ADD CONSTRAINT educacenso_cod_escola_pkey PRIMARY KEY (id);


--
-- Name: educacenso_cod_turma educacenso_cod_turma_pkey; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.educacenso_cod_turma
    ADD CONSTRAINT educacenso_cod_turma_pkey PRIMARY KEY (id);


--
-- Name: educacenso_curso_superior educacenso_curso_superior_pk; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.educacenso_curso_superior
    ADD CONSTRAINT educacenso_curso_superior_pk PRIMARY KEY (id);


--
-- Name: educacenso_ies educacenso_ies_pk; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.educacenso_ies
    ADD CONSTRAINT educacenso_ies_pk PRIMARY KEY (id);


--
-- Name: educacenso_matricula educacenso_matricula_pkey; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.educacenso_matricula
    ADD CONSTRAINT educacenso_matricula_pkey PRIMARY KEY (id);


--
-- Name: etapas_curso_educacenso etapas_curso_educacenso_pk; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.etapas_curso_educacenso
    ADD CONSTRAINT etapas_curso_educacenso_pk PRIMARY KEY (etapa_id, curso_id);


--
-- Name: etapas_educacenso etapas_educacenso_pk; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.etapas_educacenso
    ADD CONSTRAINT etapas_educacenso_pk PRIMARY KEY (id);


--
-- Name: falta_aluno falta_aluno_pkey; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.falta_aluno
    ADD CONSTRAINT falta_aluno_pkey PRIMARY KEY (id);


--
-- Name: falta_componente_curricular falta_componente_curricular_pkey; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.falta_componente_curricular
    ADD CONSTRAINT falta_componente_curricular_pkey PRIMARY KEY (falta_aluno_id, componente_curricular_id, etapa);


--
-- Name: falta_geral falta_geral_pkey; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.falta_geral
    ADD CONSTRAINT falta_geral_pkey PRIMARY KEY (falta_aluno_id, etapa);


--
-- Name: ficha_medica_aluno ficha_medica_cod_aluno_pkey; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.ficha_medica_aluno
    ADD CONSTRAINT ficha_medica_cod_aluno_pkey PRIMARY KEY (ref_cod_aluno);


--
-- Name: formula_media formula_media_pkey; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.formula_media
    ADD CONSTRAINT formula_media_pkey PRIMARY KEY (id, instituicao_id);


--
-- Name: lingua_indigena_educacenso lingua_indigena_educacenso_pk; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.lingua_indigena_educacenso
    ADD CONSTRAINT lingua_indigena_educacenso_pk PRIMARY KEY (id);


--
-- Name: media_geral media_geral_pkey; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.media_geral
    ADD CONSTRAINT media_geral_pkey PRIMARY KEY (nota_aluno_id, etapa);


--
-- Name: educacenso_cod_aluno modules_educacenso_cod_aluno_cod_aluno_cod_aluno_inep_unique; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.educacenso_cod_aluno
    ADD CONSTRAINT modules_educacenso_cod_aluno_cod_aluno_cod_aluno_inep_unique UNIQUE (cod_aluno, cod_aluno_inep);


--
-- Name: educacenso_cod_docente modules_educacenso_cod_docente_cod_servidor_cod_docente_inep_un; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.educacenso_cod_docente
    ADD CONSTRAINT modules_educacenso_cod_docente_cod_servidor_cod_docente_inep_un UNIQUE (cod_servidor, cod_docente_inep);


--
-- Name: educacenso_cod_escola modules_educacenso_cod_escola_cod_escola_cod_escola_inep_unique; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.educacenso_cod_escola
    ADD CONSTRAINT modules_educacenso_cod_escola_cod_escola_cod_escola_inep_unique UNIQUE (cod_escola, cod_escola_inep);


--
-- Name: educacenso_cod_turma modules_educacenso_cod_turma_cod_turma_cod_turma_inep_unique; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.educacenso_cod_turma
    ADD CONSTRAINT modules_educacenso_cod_turma_cod_turma_cod_turma_inep_unique UNIQUE (cod_turma, cod_turma_inep);


--
-- Name: falta_aluno modules_falta_aluno_matricula_id_unique; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.falta_aluno
    ADD CONSTRAINT modules_falta_aluno_matricula_id_unique UNIQUE (matricula_id);


--
-- Name: nota_aluno modules_nota_aluno_matricula_id_unique; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.nota_aluno
    ADD CONSTRAINT modules_nota_aluno_matricula_id_unique UNIQUE (matricula_id);


--
-- Name: parecer_aluno modules_parecer_aluno_matricula_id_unique; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.parecer_aluno
    ADD CONSTRAINT modules_parecer_aluno_matricula_id_unique UNIQUE (matricula_id);


--
-- Name: moradia_aluno moradia_aluno_pkei; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.moradia_aluno
    ADD CONSTRAINT moradia_aluno_pkei PRIMARY KEY (ref_cod_aluno);


--
-- Name: nota_aluno nota_aluno_pkey; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.nota_aluno
    ADD CONSTRAINT nota_aluno_pkey PRIMARY KEY (id);


--
-- Name: nota_componente_curricular_media nota_componente_curricular_media_pkey; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.nota_componente_curricular_media
    ADD CONSTRAINT nota_componente_curricular_media_pkey PRIMARY KEY (nota_aluno_id, componente_curricular_id);


--
-- Name: nota_componente_curricular nota_componente_curricular_pkey; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.nota_componente_curricular
    ADD CONSTRAINT nota_componente_curricular_pkey PRIMARY KEY (nota_aluno_id, componente_curricular_id, etapa);


--
-- Name: nota_geral nota_geral_pkey; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.nota_geral
    ADD CONSTRAINT nota_geral_pkey PRIMARY KEY (id);


--
-- Name: parecer_aluno parecer_aluno_pkey; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.parecer_aluno
    ADD CONSTRAINT parecer_aluno_pkey PRIMARY KEY (id);


--
-- Name: parecer_componente_curricular parecer_componente_curricular_pkey; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.parecer_componente_curricular
    ADD CONSTRAINT parecer_componente_curricular_pkey PRIMARY KEY (parecer_aluno_id, componente_curricular_id, etapa);


--
-- Name: parecer_geral parecer_geral_pkey; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.parecer_geral
    ADD CONSTRAINT parecer_geral_pkey PRIMARY KEY (parecer_aluno_id, etapa);


--
-- Name: educacenso_orgao_regional pk_educacenso_orgao_regional; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.educacenso_orgao_regional
    ADD CONSTRAINT pk_educacenso_orgao_regional PRIMARY KEY (sigla_uf, codigo);


--
-- Name: povo_indigena_educacenso povo_indigena_educacenso_pkey; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.povo_indigena_educacenso
    ADD CONSTRAINT povo_indigena_educacenso_pkey PRIMARY KEY (id);


--
-- Name: professor_turma_disciplina professor_turma_disciplina_pk; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.professor_turma_disciplina
    ADD CONSTRAINT professor_turma_disciplina_pk PRIMARY KEY (professor_turma_id, componente_curricular_id);


--
-- Name: professor_turma professor_turma_id_pk; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.professor_turma
    ADD CONSTRAINT professor_turma_id_pk PRIMARY KEY (id);


--
-- Name: regra_avaliacao regra_avaliacao_pkey; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.regra_avaliacao
    ADD CONSTRAINT regra_avaliacao_pkey PRIMARY KEY (id, instituicao_id);


--
-- Name: regra_avaliacao_recuperacao regra_avaliacao_recuperacao_pkey; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.regra_avaliacao_recuperacao
    ADD CONSTRAINT regra_avaliacao_recuperacao_pkey PRIMARY KEY (id);


--
-- Name: regra_avaliacao_serie_ano_excluidos regra_avaliacao_serie_ano_excluidos_pkey; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.regra_avaliacao_serie_ano_excluidos
    ADD CONSTRAINT regra_avaliacao_serie_ano_excluidos_pkey PRIMARY KEY (id);


--
-- Name: regra_avaliacao_serie_ano regra_avaliacao_serie_ano_pkey; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.regra_avaliacao_serie_ano
    ADD CONSTRAINT regra_avaliacao_serie_ano_pkey PRIMARY KEY (serie_id, ano_letivo);


--
-- Name: tabela_arredondamento tabela_arredondamento_pkey; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.tabela_arredondamento
    ADD CONSTRAINT tabela_arredondamento_pkey PRIMARY KEY (id, instituicao_id);


--
-- Name: tabela_arredondamento_valor tabela_arredondamento_valor_pkey; Type: CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.tabela_arredondamento_valor
    ADD CONSTRAINT tabela_arredondamento_valor_pkey PRIMARY KEY (id);


--
-- Name: aluno_aluno_beneficio aluno_aluno_beneficio_aluno_id_aluno_beneficio_id_unique; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.aluno_aluno_beneficio
    ADD CONSTRAINT aluno_aluno_beneficio_aluno_id_aluno_beneficio_id_unique UNIQUE (aluno_id, aluno_beneficio_id);


--
-- Name: aluno_aluno_beneficio aluno_aluno_beneficio_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.aluno_aluno_beneficio
    ADD CONSTRAINT aluno_aluno_beneficio_pkey PRIMARY KEY (id);


--
-- Name: aluno_beneficio aluno_beneficio_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.aluno_beneficio
    ADD CONSTRAINT aluno_beneficio_pkey PRIMARY KEY (cod_aluno_beneficio);


--
-- Name: aluno_excluidos aluno_excluidos_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.aluno_excluidos
    ADD CONSTRAINT aluno_excluidos_pkey PRIMARY KEY (cod_aluno);


--
-- Name: aluno_historico_altura_peso aluno_historico_altura_peso_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.aluno_historico_altura_peso
    ADD CONSTRAINT aluno_historico_altura_peso_pkey PRIMARY KEY (id);


--
-- Name: aluno aluno_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.aluno
    ADD CONSTRAINT aluno_pkey PRIMARY KEY (cod_aluno);


--
-- Name: aluno aluno_ref_idpes_un; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.aluno
    ADD CONSTRAINT aluno_ref_idpes_un UNIQUE (ref_idpes);


--
-- Name: ano_letivo_modulo ano_letivo_modulo_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.ano_letivo_modulo
    ADD CONSTRAINT ano_letivo_modulo_pkey PRIMARY KEY (id);


--
-- Name: ano_letivo_modulo ano_letivo_modulo_ref_ano_ref_ref_cod_escola_sequencial_ref_cod; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.ano_letivo_modulo
    ADD CONSTRAINT ano_letivo_modulo_ref_ano_ref_ref_cod_escola_sequencial_ref_cod UNIQUE (ref_ano, ref_ref_cod_escola, sequencial, ref_cod_modulo);


--
-- Name: backup backup_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.backup
    ADD CONSTRAINT backup_pkey PRIMARY KEY (id);


--
-- Name: busca_ativa busca_ativa_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.busca_ativa
    ADD CONSTRAINT busca_ativa_pkey PRIMARY KEY (id);


--
-- Name: calendario_ano_letivo calendario_ano_letivo_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.calendario_ano_letivo
    ADD CONSTRAINT calendario_ano_letivo_pkey PRIMARY KEY (cod_calendario_ano_letivo);


--
-- Name: calendario_anotacao calendario_anotacao_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.calendario_anotacao
    ADD CONSTRAINT calendario_anotacao_pkey PRIMARY KEY (cod_calendario_anotacao);


--
-- Name: calendario_dia_anotacao calendario_dia_anotacao_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.calendario_dia_anotacao
    ADD CONSTRAINT calendario_dia_anotacao_pkey PRIMARY KEY (ref_dia, ref_mes, ref_ref_cod_calendario_ano_letivo, ref_cod_calendario_anotacao);


--
-- Name: calendario_dia_motivo calendario_dia_motivo_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.calendario_dia_motivo
    ADD CONSTRAINT calendario_dia_motivo_pkey PRIMARY KEY (cod_calendario_dia_motivo);


--
-- Name: calendario_dia calendario_dia_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.calendario_dia
    ADD CONSTRAINT calendario_dia_pkey PRIMARY KEY (id);


--
-- Name: disciplina_dependencia cod_disciplina_dependencia_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.disciplina_dependencia
    ADD CONSTRAINT cod_disciplina_dependencia_pkey PRIMARY KEY (cod_disciplina_dependencia);


--
-- Name: dispensa_disciplina cod_dispensa_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.dispensa_disciplina
    ADD CONSTRAINT cod_dispensa_pkey PRIMARY KEY (cod_dispensa);


--
-- Name: servidor_funcao cod_servidor_funcao_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.servidor_funcao
    ADD CONSTRAINT cod_servidor_funcao_pkey PRIMARY KEY (cod_servidor_funcao);


--
-- Name: configuracoes_gerais configuracoes_gerais_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.configuracoes_gerais
    ADD CONSTRAINT configuracoes_gerais_pkey PRIMARY KEY (ref_cod_instituicao);


--
-- Name: curso curso_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.curso
    ADD CONSTRAINT curso_pkey PRIMARY KEY (cod_curso);


--
-- Name: disciplina_serie disciplina_serie_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.disciplina_serie
    ADD CONSTRAINT disciplina_serie_pkey PRIMARY KEY (ref_cod_disciplina, ref_cod_serie);


--
-- Name: escola_ano_letivo escola_ano_letivo_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.escola_ano_letivo
    ADD CONSTRAINT escola_ano_letivo_pkey PRIMARY KEY (id);


--
-- Name: escola_ano_letivo escola_ano_letivo_ref_cod_escola_ano_unique; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.escola_ano_letivo
    ADD CONSTRAINT escola_ano_letivo_ref_cod_escola_ano_unique UNIQUE (ref_cod_escola, ano);


--
-- Name: escola_complemento escola_complemento_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.escola_complemento
    ADD CONSTRAINT escola_complemento_pkey PRIMARY KEY (ref_cod_escola);


--
-- Name: escola_curso escola_curso_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.escola_curso
    ADD CONSTRAINT escola_curso_pkey PRIMARY KEY (ref_cod_escola, ref_cod_curso);


--
-- Name: escola_localizacao escola_localizacao_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.escola_localizacao
    ADD CONSTRAINT escola_localizacao_pkey PRIMARY KEY (cod_escola_localizacao);


--
-- Name: escola escola_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.escola
    ADD CONSTRAINT escola_pkey PRIMARY KEY (cod_escola);


--
-- Name: escola_serie_disciplina_excluidos escola_serie_disciplina_excluidos_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.escola_serie_disciplina_excluidos
    ADD CONSTRAINT escola_serie_disciplina_excluidos_pkey PRIMARY KEY (id);


--
-- Name: escola_serie_disciplina escola_serie_disciplina_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.escola_serie_disciplina
    ADD CONSTRAINT escola_serie_disciplina_pkey PRIMARY KEY (id);


--
-- Name: escola_serie escola_serie_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.escola_serie
    ADD CONSTRAINT escola_serie_pkey PRIMARY KEY (ref_cod_escola, ref_cod_serie);


--
-- Name: escola_usuario escola_usuario_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.escola_usuario
    ADD CONSTRAINT escola_usuario_pkey PRIMARY KEY (id);


--
-- Name: falta_atraso_compensado falta_atraso_compensado_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.falta_atraso_compensado
    ADD CONSTRAINT falta_atraso_compensado_pkey PRIMARY KEY (cod_compensado);


--
-- Name: falta_atraso falta_atraso_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.falta_atraso
    ADD CONSTRAINT falta_atraso_pkey PRIMARY KEY (cod_falta_atraso);


--
-- Name: bloqueio_lancamento_faltas_notas fk_bloqueio_lancamento_faltas_notas; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.bloqueio_lancamento_faltas_notas
    ADD CONSTRAINT fk_bloqueio_lancamento_faltas_notas PRIMARY KEY (cod_bloqueio);


--
-- Name: funcao funcao_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.funcao
    ADD CONSTRAINT funcao_pkey PRIMARY KEY (cod_funcao);


--
-- Name: historico_disciplinas historico_disciplinas_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.historico_disciplinas
    ADD CONSTRAINT historico_disciplinas_pkey PRIMARY KEY (id);


--
-- Name: historico_escolar historico_escolar_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.historico_escolar
    ADD CONSTRAINT historico_escolar_pkey PRIMARY KEY (id);


--
-- Name: historico_grade_curso historico_grade_curso_pk; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.historico_grade_curso
    ADD CONSTRAINT historico_grade_curso_pk PRIMARY KEY (id);


--
-- Name: instituicao_documentacao instituicao_documentacao_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.instituicao_documentacao
    ADD CONSTRAINT instituicao_documentacao_pkey PRIMARY KEY (id);


--
-- Name: instituicao instituicao_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.instituicao
    ADD CONSTRAINT instituicao_pkey PRIMARY KEY (cod_instituicao);


--
-- Name: matricula_ocorrencia_disciplinar matricula_ocorrencia_disciplinar_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.matricula_ocorrencia_disciplinar
    ADD CONSTRAINT matricula_ocorrencia_disciplinar_pkey PRIMARY KEY (cod_ocorrencia_disciplinar);


--
-- Name: matricula matricula_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.matricula
    ADD CONSTRAINT matricula_pkey PRIMARY KEY (cod_matricula);


--
-- Name: matricula_turma_excluidos matricula_turma_excluidos_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.matricula_turma_excluidos
    ADD CONSTRAINT matricula_turma_excluidos_pkey PRIMARY KEY (id);


--
-- Name: matricula_turma matricula_turma_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.matricula_turma
    ADD CONSTRAINT matricula_turma_pkey PRIMARY KEY (id);


--
-- Name: menu_tipo_usuario menu_tipo_usuario_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.menu_tipo_usuario
    ADD CONSTRAINT menu_tipo_usuario_pkey PRIMARY KEY (ref_cod_tipo_usuario, menu_id);


--
-- Name: modulo modulo_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.modulo
    ADD CONSTRAINT modulo_pkey PRIMARY KEY (cod_modulo);


--
-- Name: motivo_afastamento motivo_afastamento_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.motivo_afastamento
    ADD CONSTRAINT motivo_afastamento_pkey PRIMARY KEY (cod_motivo_afastamento);


--
-- Name: nivel_ensino nivel_ensino_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.nivel_ensino
    ADD CONSTRAINT nivel_ensino_pkey PRIMARY KEY (cod_nivel_ensino);


--
-- Name: abandono_tipo pk_cod_abandono_tipo; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.abandono_tipo
    ADD CONSTRAINT pk_cod_abandono_tipo PRIMARY KEY (cod_abandono_tipo);


--
-- Name: bloqueio_ano_letivo pmieducar_bloqueio_ano_letivo_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.bloqueio_ano_letivo
    ADD CONSTRAINT pmieducar_bloqueio_ano_letivo_pkey PRIMARY KEY (ref_cod_instituicao, ref_ano);


--
-- Name: calendario_dia pmieducar_calendario_dia_ref_cod_calendario_ano_letivo_mes_dia_; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.calendario_dia
    ADD CONSTRAINT pmieducar_calendario_dia_ref_cod_calendario_ano_letivo_mes_dia_ UNIQUE (ref_cod_calendario_ano_letivo, mes, dia);


--
-- Name: matricula_ocorrencia_disciplinar pmieducar_matricula_ocorrencia_disciplinar_ref_cod_matricula_re; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.matricula_ocorrencia_disciplinar
    ADD CONSTRAINT pmieducar_matricula_ocorrencia_disciplinar_ref_cod_matricula_re UNIQUE (ref_cod_matricula, ref_cod_tipo_ocorrencia_disciplinar, sequencial);


--
-- Name: projeto pmieducar_projeto_cod_projeto; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.projeto
    ADD CONSTRAINT pmieducar_projeto_cod_projeto PRIMARY KEY (cod_projeto);


--
-- Name: sequencia_serie pmieducar_sequencia_serie_ref_serie_origem_ref_serie_destino_un; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.sequencia_serie
    ADD CONSTRAINT pmieducar_sequencia_serie_ref_serie_origem_ref_serie_destino_un UNIQUE (ref_serie_origem, ref_serie_destino);


--
-- Name: projeto_aluno projeto_aluno_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.projeto_aluno
    ADD CONSTRAINT projeto_aluno_pkey PRIMARY KEY (id);


--
-- Name: quadro_horario_horarios_aux quadro_horario_horarios_aux_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.quadro_horario_horarios_aux
    ADD CONSTRAINT quadro_horario_horarios_aux_pkey PRIMARY KEY (ref_cod_quadro_horario, sequencial);


--
-- Name: quadro_horario_horarios quadro_horario_horarios_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.quadro_horario_horarios
    ADD CONSTRAINT quadro_horario_horarios_pkey PRIMARY KEY (ref_cod_quadro_horario, sequencial);


--
-- Name: quadro_horario quadro_horario_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.quadro_horario
    ADD CONSTRAINT quadro_horario_pkey PRIMARY KEY (cod_quadro_horario);


--
-- Name: religions religiao_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.religions
    ADD CONSTRAINT religiao_pkey PRIMARY KEY (id);


--
-- Name: sequencia_serie sequencia_serie_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.sequencia_serie
    ADD CONSTRAINT sequencia_serie_pkey PRIMARY KEY (id);


--
-- Name: serie serie_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.serie
    ADD CONSTRAINT serie_pkey PRIMARY KEY (cod_serie);


--
-- Name: servidor_afastamento servidor_afastamento_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.servidor_afastamento
    ADD CONSTRAINT servidor_afastamento_pkey PRIMARY KEY (id);


--
-- Name: servidor_afastamento servidor_afastamento_ref_cod_servidor_sequencial_ref_ref_cod_in; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.servidor_afastamento
    ADD CONSTRAINT servidor_afastamento_ref_cod_servidor_sequencial_ref_ref_cod_in UNIQUE (ref_cod_servidor, sequencial, ref_ref_cod_instituicao);


--
-- Name: servidor_alocacao servidor_alocacao_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.servidor_alocacao
    ADD CONSTRAINT servidor_alocacao_pkey PRIMARY KEY (cod_servidor_alocacao);


--
-- Name: servidor_curso_ministra servidor_cuso_ministra_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.servidor_curso_ministra
    ADD CONSTRAINT servidor_cuso_ministra_pkey PRIMARY KEY (ref_cod_curso, ref_ref_cod_instituicao, ref_cod_servidor);


--
-- Name: servidor_disciplina servidor_disciplina_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.servidor_disciplina
    ADD CONSTRAINT servidor_disciplina_pkey PRIMARY KEY (ref_cod_disciplina, ref_ref_cod_instituicao, ref_cod_servidor, ref_cod_curso, ref_cod_funcao);


--
-- Name: servidor_frequencia servidor_frequencia_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.servidor_frequencia
    ADD CONSTRAINT servidor_frequencia_pkey PRIMARY KEY (id);


--
-- Name: servidor servidor_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.servidor
    ADD CONSTRAINT servidor_pkey PRIMARY KEY (cod_servidor, ref_cod_instituicao);


--
-- Name: tipo_dispensa tipo_dispensa_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.tipo_dispensa
    ADD CONSTRAINT tipo_dispensa_pkey PRIMARY KEY (cod_tipo_dispensa);


--
-- Name: tipo_ensino tipo_ensino_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.tipo_ensino
    ADD CONSTRAINT tipo_ensino_pkey PRIMARY KEY (cod_tipo_ensino);


--
-- Name: tipo_ocorrencia_disciplinar tipo_ocorrencia_disciplinar_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.tipo_ocorrencia_disciplinar
    ADD CONSTRAINT tipo_ocorrencia_disciplinar_pkey PRIMARY KEY (cod_tipo_ocorrencia_disciplinar);


--
-- Name: tipo_regime tipo_regime_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.tipo_regime
    ADD CONSTRAINT tipo_regime_pkey PRIMARY KEY (cod_tipo_regime);


--
-- Name: tipo_usuario tipo_usuario_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.tipo_usuario
    ADD CONSTRAINT tipo_usuario_pkey PRIMARY KEY (cod_tipo_usuario);


--
-- Name: transferencia_solicitacao transferencia_solicitacao_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.transferencia_solicitacao
    ADD CONSTRAINT transferencia_solicitacao_pkey PRIMARY KEY (cod_transferencia_solicitacao);


--
-- Name: transferencia_tipo transferencia_tipo_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.transferencia_tipo
    ADD CONSTRAINT transferencia_tipo_pkey PRIMARY KEY (cod_transferencia_tipo);


--
-- Name: turma_modulo turma_modulo_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.turma_modulo
    ADD CONSTRAINT turma_modulo_pkey PRIMARY KEY (ref_cod_turma, ref_cod_modulo, sequencial);


--
-- Name: turma turma_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.turma
    ADD CONSTRAINT turma_pkey PRIMARY KEY (cod_turma);


--
-- Name: turma_serie turma_serie_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.turma_serie
    ADD CONSTRAINT turma_serie_pkey PRIMARY KEY (id);


--
-- Name: turma_tipo turma_tipo_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.turma_tipo
    ADD CONSTRAINT turma_tipo_pkey PRIMARY KEY (cod_turma_tipo);


--
-- Name: turma_turno turma_turno_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.turma_turno
    ADD CONSTRAINT turma_turno_pkey PRIMARY KEY (id);


--
-- Name: usuario usuario_pkey; Type: CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.usuario
    ADD CONSTRAINT usuario_pkey PRIMARY KEY (cod_usuario);


--
-- Name: acesso acesso_pk; Type: CONSTRAINT; Schema: portal; Owner: -
--

ALTER TABLE ONLY portal.acesso
    ADD CONSTRAINT acesso_pk PRIMARY KEY (cod_acesso);


--
-- Name: agenda_compromisso agenda_compromisso_pkey; Type: CONSTRAINT; Schema: portal; Owner: -
--

ALTER TABLE ONLY portal.agenda_compromisso
    ADD CONSTRAINT agenda_compromisso_pkey PRIMARY KEY (cod_agenda_compromisso, versao, ref_cod_agenda);


--
-- Name: agenda agenda_pkey; Type: CONSTRAINT; Schema: portal; Owner: -
--

ALTER TABLE ONLY portal.agenda
    ADD CONSTRAINT agenda_pkey PRIMARY KEY (cod_agenda);


--
-- Name: agenda_responsavel agenda_responsavel_pkey; Type: CONSTRAINT; Schema: portal; Owner: -
--

ALTER TABLE ONLY portal.agenda_responsavel
    ADD CONSTRAINT agenda_responsavel_pkey PRIMARY KEY (ref_cod_agenda, ref_ref_cod_pessoa_fj);


--
-- Name: funcionario funcionario_pk; Type: CONSTRAINT; Schema: portal; Owner: -
--

ALTER TABLE ONLY portal.funcionario
    ADD CONSTRAINT funcionario_pk PRIMARY KEY (ref_cod_pessoa_fj);


--
-- Name: funcionario_vinculo funcionario_vinculo_pk; Type: CONSTRAINT; Schema: portal; Owner: -
--

ALTER TABLE ONLY portal.funcionario_vinculo
    ADD CONSTRAINT funcionario_vinculo_pk PRIMARY KEY (cod_funcionario_vinculo);


--
-- Name: cities cities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cities
    ADD CONSTRAINT cities_pkey PRIMARY KEY (id);


--
-- Name: countries countries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.countries
    ADD CONSTRAINT countries_pkey PRIMARY KEY (id);


--
-- Name: districts districts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.districts
    ADD CONSTRAINT districts_pkey PRIMARY KEY (id);


--
-- Name: educacenso_imports educacenso_imports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.educacenso_imports
    ADD CONSTRAINT educacenso_imports_pkey PRIMARY KEY (id);


--
-- Name: employee_graduation_disciplines employee_graduation_disciplines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_graduation_disciplines
    ADD CONSTRAINT employee_graduation_disciplines_pkey PRIMARY KEY (id);


--
-- Name: employee_graduations employee_graduations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_graduations
    ADD CONSTRAINT employee_graduations_pkey PRIMARY KEY (id);


--
-- Name: ieducar_audit ieducar_audit_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ieducar_audit
    ADD CONSTRAINT ieducar_audit_pkey PRIMARY KEY (id);


--
-- Name: log_unification_old_data log_unification_old_data_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.log_unification_old_data
    ADD CONSTRAINT log_unification_old_data_pkey PRIMARY KEY (id);


--
-- Name: log_unifications log_unifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.log_unifications
    ADD CONSTRAINT log_unifications_pkey PRIMARY KEY (id);


--
-- Name: manager_access_criterias manager_access_criterias_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manager_access_criterias
    ADD CONSTRAINT manager_access_criterias_pkey PRIMARY KEY (id);


--
-- Name: manager_link_types manager_link_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manager_link_types
    ADD CONSTRAINT manager_link_types_pkey PRIMARY KEY (id);


--
-- Name: manager_roles manager_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manager_roles
    ADD CONSTRAINT manager_roles_pkey PRIMARY KEY (id);


--
-- Name: menus menus_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menus
    ADD CONSTRAINT menus_pkey PRIMARY KEY (id);


--
-- Name: migrations migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.migrations
    ADD CONSTRAINT migrations_pkey PRIMARY KEY (id);


--
-- Name: personal_access_tokens personal_access_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personal_access_tokens
    ADD CONSTRAINT personal_access_tokens_pkey PRIMARY KEY (id);


--
-- Name: personal_access_tokens personal_access_tokens_token_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personal_access_tokens
    ADD CONSTRAINT personal_access_tokens_token_unique UNIQUE (token);


--
-- Name: users users_email_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_unique UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: situacao_matricula situacao_matricula_pkey; Type: CONSTRAINT; Schema: relatorio; Owner: -
--

ALTER TABLE ONLY relatorio.situacao_matricula
    ADD CONSTRAINT situacao_matricula_pkey PRIMARY KEY (cod_situacao);


--
-- Name: cadastro_pessoa_slug_index; Type: INDEX; Schema: cadastro; Owner: -
--

CREATE INDEX cadastro_pessoa_slug_index ON cadastro.pessoa USING btree (slug);


--
-- Name: un_juridica_cnpj; Type: INDEX; Schema: cadastro; Owner: -
--

CREATE UNIQUE INDEX un_juridica_cnpj ON cadastro.juridica USING btree (cnpj);


--
-- Name: alunocomponenteetapa; Type: INDEX; Schema: modules; Owner: -
--

CREATE UNIQUE INDEX alunocomponenteetapa ON modules.parecer_componente_curricular USING btree (parecer_aluno_id, componente_curricular_id, etapa);


--
-- Name: area_conhecimento_nome_key; Type: INDEX; Schema: modules; Owner: -
--

CREATE INDEX area_conhecimento_nome_key ON modules.area_conhecimento USING btree (nome);


--
-- Name: componente_curricular_area_conhecimento_key; Type: INDEX; Schema: modules; Owner: -
--

CREATE INDEX componente_curricular_area_conhecimento_key ON modules.componente_curricular USING btree (area_conhecimento_id);


--
-- Name: componente_curricular_id_key; Type: INDEX; Schema: modules; Owner: -
--

CREATE UNIQUE INDEX componente_curricular_id_key ON modules.componente_curricular USING btree (id);


--
-- Name: componente_curricular_turma_turma_idx; Type: INDEX; Schema: modules; Owner: -
--

CREATE INDEX componente_curricular_turma_turma_idx ON modules.componente_curricular_turma USING btree (turma_id);


--
-- Name: idx_educacenso_ies_ies_id; Type: INDEX; Schema: modules; Owner: -
--

CREATE INDEX idx_educacenso_ies_ies_id ON modules.educacenso_ies USING btree (ies_id);


--
-- Name: idx_falta_aluno_matricula_id; Type: INDEX; Schema: modules; Owner: -
--

CREATE INDEX idx_falta_aluno_matricula_id ON modules.falta_aluno USING btree (matricula_id);


--
-- Name: idx_falta_aluno_matricula_id_tipo; Type: INDEX; Schema: modules; Owner: -
--

CREATE INDEX idx_falta_aluno_matricula_id_tipo ON modules.falta_aluno USING btree (matricula_id, tipo_falta);


--
-- Name: idx_falta_componente_curricular_id1; Type: INDEX; Schema: modules; Owner: -
--

CREATE INDEX idx_falta_componente_curricular_id1 ON modules.falta_componente_curricular USING btree (falta_aluno_id, componente_curricular_id, etapa);


--
-- Name: idx_falta_geral_falta_aluno_id; Type: INDEX; Schema: modules; Owner: -
--

CREATE INDEX idx_falta_geral_falta_aluno_id ON modules.falta_geral USING btree (falta_aluno_id);


--
-- Name: idx_nota_aluno_matricula; Type: INDEX; Schema: modules; Owner: -
--

CREATE INDEX idx_nota_aluno_matricula ON modules.nota_aluno USING btree (matricula_id);


--
-- Name: idx_nota_aluno_matricula_id; Type: INDEX; Schema: modules; Owner: -
--

CREATE INDEX idx_nota_aluno_matricula_id ON modules.nota_aluno USING btree (id, matricula_id);


--
-- Name: idx_nota_componente_curricular_etapa; Type: INDEX; Schema: modules; Owner: -
--

CREATE INDEX idx_nota_componente_curricular_etapa ON modules.nota_componente_curricular USING btree (nota_aluno_id, componente_curricular_id, etapa);


--
-- Name: idx_nota_componente_curricular_etp; Type: INDEX; Schema: modules; Owner: -
--

CREATE INDEX idx_nota_componente_curricular_etp ON modules.nota_componente_curricular USING btree (componente_curricular_id, etapa);


--
-- Name: idx_nota_componente_curricular_id; Type: INDEX; Schema: modules; Owner: -
--

CREATE INDEX idx_nota_componente_curricular_id ON modules.nota_componente_curricular USING btree (componente_curricular_id);


--
-- Name: idx_parecer_aluno_matricula_id; Type: INDEX; Schema: modules; Owner: -
--

CREATE INDEX idx_parecer_aluno_matricula_id ON modules.parecer_aluno USING btree (matricula_id);


--
-- Name: idx_parecer_geral_parecer_aluno_etp; Type: INDEX; Schema: modules; Owner: -
--

CREATE INDEX idx_parecer_geral_parecer_aluno_etp ON modules.parecer_geral USING btree (parecer_aluno_id, etapa);


--
-- Name: idx_tabela_arredondamento_valor_tabela_id; Type: INDEX; Schema: modules; Owner: -
--

CREATE INDEX idx_tabela_arredondamento_valor_tabela_id ON modules.tabela_arredondamento_valor USING btree (tabela_arredondamento_id);


--
-- Name: modules_falta_componente_curricular_id_index; Type: INDEX; Schema: modules; Owner: -
--

CREATE INDEX modules_falta_componente_curricular_id_index ON modules.falta_componente_curricular USING btree (id);


--
-- Name: modules_falta_geral_id_index; Type: INDEX; Schema: modules; Owner: -
--

CREATE INDEX modules_falta_geral_id_index ON modules.falta_geral USING btree (id);


--
-- Name: modules_nota_componente_curricular_id_index; Type: INDEX; Schema: modules; Owner: -
--

CREATE INDEX modules_nota_componente_curricular_id_index ON modules.nota_componente_curricular USING btree (id);


--
-- Name: modules_nota_componente_curricular_media_componente_curricular_; Type: INDEX; Schema: modules; Owner: -
--

CREATE INDEX modules_nota_componente_curricular_media_componente_curricular_ ON modules.nota_componente_curricular_media USING btree (componente_curricular_id);


--
-- Name: modules_nota_componente_curricular_media_etapa_index; Type: INDEX; Schema: modules; Owner: -
--

CREATE INDEX modules_nota_componente_curricular_media_etapa_index ON modules.nota_componente_curricular_media USING btree (etapa);


--
-- Name: modules_nota_componente_curricular_media_nota_aluno_id_index; Type: INDEX; Schema: modules; Owner: -
--

CREATE INDEX modules_nota_componente_curricular_media_nota_aluno_id_index ON modules.nota_componente_curricular_media USING btree (nota_aluno_id);


--
-- Name: modules_nota_exame_ref_cod_componente_curricular_index; Type: INDEX; Schema: modules; Owner: -
--

CREATE INDEX modules_nota_exame_ref_cod_componente_curricular_index ON modules.nota_exame USING btree (ref_cod_componente_curricular);


--
-- Name: modules_nota_exame_ref_cod_matricula_index; Type: INDEX; Schema: modules; Owner: -
--

CREATE INDEX modules_nota_exame_ref_cod_matricula_index ON modules.nota_exame USING btree (ref_cod_matricula);


--
-- Name: modules_nota_geral_etapa_index; Type: INDEX; Schema: modules; Owner: -
--

CREATE INDEX modules_nota_geral_etapa_index ON modules.nota_geral USING btree (etapa);


--
-- Name: modules_nota_geral_nota_aluno_id_index; Type: INDEX; Schema: modules; Owner: -
--

CREATE INDEX modules_nota_geral_nota_aluno_id_index ON modules.nota_geral USING btree (nota_aluno_id);


--
-- Name: modules_parecer_componente_curricular_id_index; Type: INDEX; Schema: modules; Owner: -
--

CREATE INDEX modules_parecer_componente_curricular_id_index ON modules.parecer_componente_curricular USING btree (id);


--
-- Name: modules_parecer_geral_id_index; Type: INDEX; Schema: modules; Owner: -
--

CREATE INDEX modules_parecer_geral_id_index ON modules.parecer_geral USING btree (id);


--
-- Name: regra_avaliacao_id_key; Type: INDEX; Schema: modules; Owner: -
--

CREATE UNIQUE INDEX regra_avaliacao_id_key ON modules.regra_avaliacao USING btree (id);


--
-- Name: tabela_arredondamento_id_key; Type: INDEX; Schema: modules; Owner: -
--

CREATE UNIQUE INDEX tabela_arredondamento_id_key ON modules.tabela_arredondamento USING btree (id);


--
-- Name: escola_ano_letivo_ref_cod_escola_ano_index; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX escola_ano_letivo_ref_cod_escola_ano_index ON pmieducar.escola_ano_letivo USING btree (ref_cod_escola, ano);


--
-- Name: historico_escolar_ano_idx; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX historico_escolar_ano_idx ON pmieducar.historico_escolar USING btree (ano);


--
-- Name: historico_escolar_ativo_idx; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX historico_escolar_ativo_idx ON pmieducar.historico_escolar USING btree (ativo);


--
-- Name: historico_escolar_nm_serie_idx; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX historico_escolar_nm_serie_idx ON pmieducar.historico_escolar USING btree (nm_serie);


--
-- Name: i_aluno_ativo; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_aluno_ativo ON pmieducar.aluno USING btree (ativo);


--
-- Name: i_aluno_beneficio_ativo; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_aluno_beneficio_ativo ON pmieducar.aluno_beneficio USING btree (ativo);


--
-- Name: i_aluno_beneficio_nm_beneficio; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_aluno_beneficio_nm_beneficio ON pmieducar.aluno_beneficio USING btree (nm_beneficio);


--
-- Name: i_aluno_beneficio_ref_usuario_cad; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_aluno_beneficio_ref_usuario_cad ON pmieducar.aluno_beneficio USING btree (ref_usuario_cad);


--
-- Name: i_aluno_ref_cod_religiao; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_aluno_ref_cod_religiao ON pmieducar.aluno USING btree (ref_cod_religiao);


--
-- Name: i_aluno_ref_idpes; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_aluno_ref_idpes ON pmieducar.aluno USING btree (ref_idpes);


--
-- Name: i_aluno_ref_usuario_cad; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_aluno_ref_usuario_cad ON pmieducar.aluno USING btree (ref_usuario_cad);


--
-- Name: i_calendario_ano_letivo_ano; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_calendario_ano_letivo_ano ON pmieducar.calendario_ano_letivo USING btree (ano);


--
-- Name: i_calendario_ano_letivo_ativo; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_calendario_ano_letivo_ativo ON pmieducar.calendario_ano_letivo USING btree (ativo);


--
-- Name: i_calendario_ano_letivo_ref_cod_escola; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_calendario_ano_letivo_ref_cod_escola ON pmieducar.calendario_ano_letivo USING btree (ref_cod_escola);


--
-- Name: i_calendario_ano_letivo_ref_usuario_cad; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_calendario_ano_letivo_ref_usuario_cad ON pmieducar.calendario_ano_letivo USING btree (ref_usuario_cad);


--
-- Name: i_calendario_dia_motivo_ativo; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_calendario_dia_motivo_ativo ON pmieducar.calendario_dia_motivo USING btree (ativo);


--
-- Name: i_calendario_dia_motivo_ref_cod_escola; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_calendario_dia_motivo_ref_cod_escola ON pmieducar.calendario_dia_motivo USING btree (ref_cod_escola);


--
-- Name: i_calendario_dia_motivo_ref_usuario_cad; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_calendario_dia_motivo_ref_usuario_cad ON pmieducar.calendario_dia_motivo USING btree (ref_usuario_cad);


--
-- Name: i_calendario_dia_motivo_sigla; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_calendario_dia_motivo_sigla ON pmieducar.calendario_dia_motivo USING btree (sigla);


--
-- Name: i_calendario_dia_motivo_tipo; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_calendario_dia_motivo_tipo ON pmieducar.calendario_dia_motivo USING btree (tipo);


--
-- Name: i_curso_ativo; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_curso_ativo ON pmieducar.curso USING btree (ativo);


--
-- Name: i_curso_ato_poder_publico; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_curso_ato_poder_publico ON pmieducar.curso USING btree (ato_poder_publico);


--
-- Name: i_curso_carga_horaria; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_curso_carga_horaria ON pmieducar.curso USING btree (carga_horaria);


--
-- Name: i_curso_nm_curso; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_curso_nm_curso ON pmieducar.curso USING btree (nm_curso);


--
-- Name: i_curso_objetivo_curso; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_curso_objetivo_curso ON pmieducar.curso USING btree (objetivo_curso);


--
-- Name: i_curso_qtd_etapas; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_curso_qtd_etapas ON pmieducar.curso USING btree (qtd_etapas);


--
-- Name: i_curso_ref_cod_nivel_ensino; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_curso_ref_cod_nivel_ensino ON pmieducar.curso USING btree (ref_cod_nivel_ensino);


--
-- Name: i_curso_ref_cod_tipo_ensino; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_curso_ref_cod_tipo_ensino ON pmieducar.curso USING btree (ref_cod_tipo_ensino);


--
-- Name: i_curso_ref_cod_tipo_regime; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_curso_ref_cod_tipo_regime ON pmieducar.curso USING btree (ref_cod_tipo_regime);


--
-- Name: i_curso_ref_usuario_cad; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_curso_ref_usuario_cad ON pmieducar.curso USING btree (ref_usuario_cad);


--
-- Name: i_curso_sgl_curso; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_curso_sgl_curso ON pmieducar.curso USING btree (sgl_curso);


--
-- Name: i_dispensa_disciplina_ref_cod_matricula; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_dispensa_disciplina_ref_cod_matricula ON pmieducar.dispensa_disciplina USING btree (ref_cod_matricula);


--
-- Name: i_escola_ativo; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_escola_ativo ON pmieducar.escola USING btree (ativo);


--
-- Name: i_escola_complemento_ativo; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_escola_complemento_ativo ON pmieducar.escola_complemento USING btree (ativo);


--
-- Name: i_escola_complemento_bairro; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_escola_complemento_bairro ON pmieducar.escola_complemento USING btree (bairro);


--
-- Name: i_escola_complemento_cep; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_escola_complemento_cep ON pmieducar.escola_complemento USING btree (cep);


--
-- Name: i_escola_complemento_complemento; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_escola_complemento_complemento ON pmieducar.escola_complemento USING btree (complemento);


--
-- Name: i_escola_complemento_email; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_escola_complemento_email ON pmieducar.escola_complemento USING btree (email);


--
-- Name: i_escola_complemento_logradouro; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_escola_complemento_logradouro ON pmieducar.escola_complemento USING btree (logradouro);


--
-- Name: i_escola_complemento_municipio; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_escola_complemento_municipio ON pmieducar.escola_complemento USING btree (municipio);


--
-- Name: i_escola_complemento_nm_escola; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_escola_complemento_nm_escola ON pmieducar.escola_complemento USING btree (nm_escola);


--
-- Name: i_escola_complemento_numero; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_escola_complemento_numero ON pmieducar.escola_complemento USING btree (numero);


--
-- Name: i_escola_complemento_ref_usuario_cad; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_escola_complemento_ref_usuario_cad ON pmieducar.escola_complemento USING btree (ref_usuario_cad);


--
-- Name: i_escola_curso_ativo; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_escola_curso_ativo ON pmieducar.escola_curso USING btree (ativo);


--
-- Name: i_escola_curso_ref_usuario_cad; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_escola_curso_ref_usuario_cad ON pmieducar.escola_curso USING btree (ref_usuario_cad);


--
-- Name: i_escola_localizacao_ativo; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_escola_localizacao_ativo ON pmieducar.escola_localizacao USING btree (ativo);


--
-- Name: i_escola_localizacao_nm_localizacao; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_escola_localizacao_nm_localizacao ON pmieducar.escola_localizacao USING btree (nm_localizacao);


--
-- Name: i_escola_localizacao_ref_usuario_cad; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_escola_localizacao_ref_usuario_cad ON pmieducar.escola_localizacao USING btree (ref_usuario_cad);


--
-- Name: i_escola_ref_cod_instituicao; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_escola_ref_cod_instituicao ON pmieducar.escola USING btree (ref_cod_instituicao);


--
-- Name: i_escola_ref_idpes; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_escola_ref_idpes ON pmieducar.escola USING btree (ref_idpes);


--
-- Name: i_escola_ref_usuario_cad; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_escola_ref_usuario_cad ON pmieducar.escola USING btree (ref_usuario_cad);


--
-- Name: i_escola_serie_ensino_ativo; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_escola_serie_ensino_ativo ON pmieducar.escola_serie USING btree (ativo);


--
-- Name: i_escola_serie_hora_final; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_escola_serie_hora_final ON pmieducar.escola_serie USING btree (hora_final);


--
-- Name: i_escola_serie_hora_inicial; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_escola_serie_hora_inicial ON pmieducar.escola_serie USING btree (hora_inicial);


--
-- Name: i_escola_serie_ref_usuario_cad; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_escola_serie_ref_usuario_cad ON pmieducar.escola_serie USING btree (ref_usuario_cad);


--
-- Name: i_escola_sigla; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_escola_sigla ON pmieducar.escola USING btree (sigla);


--
-- Name: i_funcao_abreviatura; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_funcao_abreviatura ON pmieducar.funcao USING btree (abreviatura);


--
-- Name: i_funcao_ativo; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_funcao_ativo ON pmieducar.funcao USING btree (ativo);


--
-- Name: i_funcao_nm_funcao; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_funcao_nm_funcao ON pmieducar.funcao USING btree (nm_funcao);


--
-- Name: i_funcao_professor; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_funcao_professor ON pmieducar.funcao USING btree (professor);


--
-- Name: i_funcao_ref_usuario_cad; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_funcao_ref_usuario_cad ON pmieducar.funcao USING btree (ref_usuario_cad);


--
-- Name: i_matricula_turma_ref_cod_turma; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_matricula_turma_ref_cod_turma ON pmieducar.matricula_turma USING btree (ref_cod_turma);


--
-- Name: i_turma_nm_turma; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX i_turma_nm_turma ON pmieducar.turma USING btree (nm_turma);


--
-- Name: idx_historico_disciplinas_id; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX idx_historico_disciplinas_id ON pmieducar.historico_disciplinas USING btree (sequencial, ref_ref_cod_aluno, ref_sequencial);


--
-- Name: idx_historico_disciplinas_id1; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX idx_historico_disciplinas_id1 ON pmieducar.historico_disciplinas USING btree (ref_ref_cod_aluno, ref_sequencial);


--
-- Name: idx_historico_escolar_aluno_ativo; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX idx_historico_escolar_aluno_ativo ON pmieducar.historico_escolar USING btree (ref_cod_aluno, ativo);


--
-- Name: idx_historico_escolar_id1; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX idx_historico_escolar_id1 ON pmieducar.historico_escolar USING btree (ref_cod_aluno, sequencial);


--
-- Name: idx_historico_escolar_id2; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX idx_historico_escolar_id2 ON pmieducar.historico_escolar USING btree (ref_cod_aluno, sequencial, ano);


--
-- Name: idx_historico_escolar_id3; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX idx_historico_escolar_id3 ON pmieducar.historico_escolar USING btree (ref_cod_aluno, ano);


--
-- Name: idx_matricula_cod_escola_aluno; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX idx_matricula_cod_escola_aluno ON pmieducar.matricula USING btree (ref_ref_cod_escola, ref_cod_aluno);


--
-- Name: idx_serie_cod_regra_avaliacao_id; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX idx_serie_cod_regra_avaliacao_id ON pmieducar.serie USING btree (cod_serie, regra_avaliacao_id);


--
-- Name: idx_serie_regra_avaliacao_id; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX idx_serie_regra_avaliacao_id ON pmieducar.serie USING btree (regra_avaliacao_id);


--
-- Name: matricula_ano_idx; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX matricula_ano_idx ON pmieducar.matricula USING btree (ano);


--
-- Name: matricula_ativo_idx; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX matricula_ativo_idx ON pmieducar.matricula USING btree (ativo);


--
-- Name: matricula_turma_uindex_matricula_turma_sequencial; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE UNIQUE INDEX matricula_turma_uindex_matricula_turma_sequencial ON pmieducar.matricula_turma USING btree (ref_cod_matricula, ref_cod_turma, sequencial);


--
-- Name: pmieducar_aluno_excluidos_ref_idpes_index; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX pmieducar_aluno_excluidos_ref_idpes_index ON pmieducar.aluno_excluidos USING btree (ref_idpes);


--
-- Name: pmieducar_dispensa_disciplina_excluidos_cod_dispensa_index; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX pmieducar_dispensa_disciplina_excluidos_cod_dispensa_index ON pmieducar.dispensa_disciplina_excluidos USING btree (cod_dispensa);


--
-- Name: pmieducar_escola_serie_disciplina_ref_ref_cod_serie_ref_ref_cod; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE UNIQUE INDEX pmieducar_escola_serie_disciplina_ref_ref_cod_serie_ref_ref_cod ON pmieducar.escola_serie_disciplina USING btree (ref_ref_cod_serie, ref_ref_cod_escola, ref_cod_disciplina);


--
-- Name: pmieducar_historico_disciplinas_sequencial_ref_ref_cod_aluno_re; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE UNIQUE INDEX pmieducar_historico_disciplinas_sequencial_ref_ref_cod_aluno_re ON pmieducar.historico_disciplinas USING btree (sequencial, ref_ref_cod_aluno, ref_sequencial);


--
-- Name: pmieducar_historico_escolar_ref_cod_aluno_sequencial_unique; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE UNIQUE INDEX pmieducar_historico_escolar_ref_cod_aluno_sequencial_unique ON pmieducar.historico_escolar USING btree (ref_cod_aluno, sequencial);


--
-- Name: pmieducar_serie_ref_cod_curso_index; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX pmieducar_serie_ref_cod_curso_index ON pmieducar.serie USING btree (ref_cod_curso);


--
-- Name: pmieducar_servidor_frequencia_servidor_id_index; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX pmieducar_servidor_frequencia_servidor_id_index ON pmieducar.servidor_frequencia USING btree (servidor_id);


--
-- Name: pmieducar_turma_ref_cod_curso_index; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX pmieducar_turma_ref_cod_curso_index ON pmieducar.turma USING btree (ref_cod_curso);


--
-- Name: pmieducar_turma_ref_ref_cod_escola_index; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX pmieducar_turma_ref_ref_cod_escola_index ON pmieducar.turma USING btree (ref_ref_cod_escola);


--
-- Name: pmieducar_turma_ref_ref_cod_serie_index; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX pmieducar_turma_ref_ref_cod_serie_index ON pmieducar.turma USING btree (ref_ref_cod_serie);


--
-- Name: pmieducar_turma_turma_turno_id_index; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX pmieducar_turma_turma_turno_id_index ON pmieducar.turma USING btree (turma_turno_id);


--
-- Name: quadro_horario_horarios_busca_horarios_idx; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX quadro_horario_horarios_busca_horarios_idx ON pmieducar.quadro_horario_horarios USING btree (ref_servidor, ref_cod_instituicao_servidor, dia_semana, hora_inicial, hora_final, ativo);


--
-- Name: servidor_alocacao_busca_horarios_idx; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX servidor_alocacao_busca_horarios_idx ON pmieducar.servidor_alocacao USING btree (ref_ref_cod_instituicao, ref_cod_escola, ativo, periodo, carga_horaria);


--
-- Name: servidor_idx; Type: INDEX; Schema: pmieducar; Owner: -
--

CREATE INDEX servidor_idx ON pmieducar.servidor USING btree (cod_servidor, ref_cod_instituicao, ativo);


--
-- Name: password_resets_email_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX password_resets_email_index ON public.password_resets USING btree (email);


--
-- Name: personal_access_tokens_tokenable_type_tokenable_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX personal_access_tokens_tokenable_type_tokenable_id_index ON public.personal_access_tokens USING btree (tokenable_type, tokenable_id);


--
-- Name: documento trg_aft_documento; Type: TRIGGER; Schema: cadastro; Owner: -
--

CREATE TRIGGER trg_aft_documento AFTER INSERT OR UPDATE ON cadastro.documento FOR EACH ROW EXECUTE FUNCTION cadastro.fcn_aft_documento();


--
-- Name: documento trg_aft_documento_provisorio; Type: TRIGGER; Schema: cadastro; Owner: -
--

CREATE TRIGGER trg_aft_documento_provisorio AFTER INSERT OR UPDATE ON cadastro.documento FOR EACH ROW EXECUTE FUNCTION cadastro.fcn_aft_documento_provisorio();


--
-- Name: deficiencia trigger_when_deleted_cadastro_deficiencia; Type: TRIGGER; Schema: cadastro; Owner: -
--

CREATE TRIGGER trigger_when_deleted_cadastro_deficiencia AFTER DELETE ON cadastro.deficiencia FOR EACH ROW EXECUTE FUNCTION public.when_deleted_cadastro_deficiencia();


--
-- Name: deficiencia update_cadastro_deficiencia; Type: TRIGGER; Schema: cadastro; Owner: -
--

CREATE TRIGGER update_cadastro_deficiencia BEFORE UPDATE ON cadastro.deficiencia FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: fisica_foto update_cadastro_fisica_foto; Type: TRIGGER; Schema: cadastro; Owner: -
--

CREATE TRIGGER update_cadastro_fisica_foto BEFORE UPDATE ON cadastro.fisica_foto FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: area_conhecimento trigger_when_deleted_modules_area_conhecimento; Type: TRIGGER; Schema: modules; Owner: -
--

CREATE TRIGGER trigger_when_deleted_modules_area_conhecimento AFTER DELETE ON modules.area_conhecimento FOR EACH ROW EXECUTE FUNCTION public.when_deleted_modules_area_conhecimento();


--
-- Name: componente_curricular_ano_escolar trigger_when_deleted_modules_componente_curricular_ano_escolar; Type: TRIGGER; Schema: modules; Owner: -
--

CREATE TRIGGER trigger_when_deleted_modules_componente_curricular_ano_escolar AFTER DELETE ON modules.componente_curricular_ano_escolar FOR EACH ROW EXECUTE FUNCTION public.when_deleted_modules_componente_curricular_ano_escolar();


--
-- Name: componente_curricular_turma trigger_when_deleted_modules_componente_curricular_turma; Type: TRIGGER; Schema: modules; Owner: -
--

CREATE TRIGGER trigger_when_deleted_modules_componente_curricular_turma AFTER DELETE ON modules.componente_curricular_turma FOR EACH ROW EXECUTE FUNCTION public.when_deleted_modules_componente_curricular_turma();


--
-- Name: professor_turma trigger_when_deleted_modules_professor_turma; Type: TRIGGER; Schema: modules; Owner: -
--

CREATE TRIGGER trigger_when_deleted_modules_professor_turma AFTER DELETE ON modules.professor_turma FOR EACH ROW EXECUTE FUNCTION public.when_deleted_modules_professor_turma();


--
-- Name: regra_avaliacao_recuperacao trigger_when_deleted_modules_regra_avaliacao_recuperacao; Type: TRIGGER; Schema: modules; Owner: -
--

CREATE TRIGGER trigger_when_deleted_modules_regra_avaliacao_recuperacao AFTER DELETE ON modules.regra_avaliacao_recuperacao FOR EACH ROW EXECUTE FUNCTION public.when_deleted_modules_regra_avaliacao_recuperacao();


--
-- Name: regra_avaliacao_serie_ano trigger_when_deleted_modules_regra_avaliacao_serie_ano; Type: TRIGGER; Schema: modules; Owner: -
--

CREATE TRIGGER trigger_when_deleted_modules_regra_avaliacao_serie_ano AFTER DELETE ON modules.regra_avaliacao_serie_ano FOR EACH ROW EXECUTE FUNCTION public.when_deleted_modules_regra_avaliacao_serie_ano();


--
-- Name: componente_curricular_turma update_componente_curricular_turma_updated_at; Type: TRIGGER; Schema: modules; Owner: -
--

CREATE TRIGGER update_componente_curricular_turma_updated_at BEFORE UPDATE ON modules.componente_curricular_turma FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: area_conhecimento update_modules_area_conhecimento; Type: TRIGGER; Schema: modules; Owner: -
--

CREATE TRIGGER update_modules_area_conhecimento BEFORE UPDATE ON modules.area_conhecimento FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: componente_curricular update_modules_componente_curricular; Type: TRIGGER; Schema: modules; Owner: -
--

CREATE TRIGGER update_modules_componente_curricular BEFORE UPDATE ON modules.componente_curricular FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: componente_curricular_ano_escolar update_modules_componente_curricular_ano_escolar; Type: TRIGGER; Schema: modules; Owner: -
--

CREATE TRIGGER update_modules_componente_curricular_ano_escolar BEFORE UPDATE ON modules.componente_curricular_ano_escolar FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: regra_avaliacao update_modules_regra_avaliacao; Type: TRIGGER; Schema: modules; Owner: -
--

CREATE TRIGGER update_modules_regra_avaliacao BEFORE UPDATE ON modules.regra_avaliacao FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: regra_avaliacao_recuperacao update_modules_regra_avaliacao_recuperacao; Type: TRIGGER; Schema: modules; Owner: -
--

CREATE TRIGGER update_modules_regra_avaliacao_recuperacao BEFORE UPDATE ON modules.regra_avaliacao_recuperacao FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: regra_avaliacao_serie_ano update_modules_regra_avaliacao_serie_ano; Type: TRIGGER; Schema: modules; Owner: -
--

CREATE TRIGGER update_modules_regra_avaliacao_serie_ano BEFORE UPDATE ON modules.regra_avaliacao_serie_ano FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: tabela_arredondamento update_modules_tabela_arredondamento; Type: TRIGGER; Schema: modules; Owner: -
--

CREATE TRIGGER update_modules_tabela_arredondamento BEFORE UPDATE ON modules.tabela_arredondamento FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: matricula retira_data_cancel_matricula_trg; Type: TRIGGER; Schema: pmieducar; Owner: -
--

CREATE TRIGGER retira_data_cancel_matricula_trg AFTER UPDATE ON pmieducar.matricula FOR EACH ROW EXECUTE FUNCTION public.retira_data_cancel_matricula_fun();


--
-- Name: matricula_turma trigger_delete_matricula_turma; Type: TRIGGER; Schema: pmieducar; Owner: -
--

CREATE TRIGGER trigger_delete_matricula_turma AFTER DELETE ON pmieducar.matricula_turma FOR EACH ROW EXECUTE FUNCTION pmieducar.delete_matricula_turma();


--
-- Name: matricula trigger_updated_at_matricula; Type: TRIGGER; Schema: pmieducar; Owner: -
--

CREATE TRIGGER trigger_updated_at_matricula BEFORE UPDATE ON pmieducar.matricula FOR EACH ROW EXECUTE FUNCTION pmieducar.updated_at_matricula();


--
-- Name: matricula_turma trigger_updated_at_matricula_turma; Type: TRIGGER; Schema: pmieducar; Owner: -
--

CREATE TRIGGER trigger_updated_at_matricula_turma BEFORE UPDATE ON pmieducar.matricula_turma FOR EACH ROW EXECUTE FUNCTION pmieducar.updated_at_matricula_turma();


--
-- Name: aluno trigger_when_deleted_pmieducar_aluno; Type: TRIGGER; Schema: pmieducar; Owner: -
--

CREATE TRIGGER trigger_when_deleted_pmieducar_aluno AFTER DELETE ON pmieducar.aluno FOR EACH ROW EXECUTE FUNCTION public.when_deleted_pmieducar_aluno();


--
-- Name: disciplina_dependencia trigger_when_deleted_pmieducar_disciplina_dependencia; Type: TRIGGER; Schema: pmieducar; Owner: -
--

CREATE TRIGGER trigger_when_deleted_pmieducar_disciplina_dependencia AFTER DELETE ON pmieducar.disciplina_dependencia FOR EACH ROW EXECUTE FUNCTION public.when_deleted_pmieducar_disciplina_dependencia();


--
-- Name: dispensa_disciplina trigger_when_deleted_pmieducar_dispensa_disciplina; Type: TRIGGER; Schema: pmieducar; Owner: -
--

CREATE TRIGGER trigger_when_deleted_pmieducar_dispensa_disciplina AFTER DELETE ON pmieducar.dispensa_disciplina FOR EACH ROW EXECUTE FUNCTION public.when_deleted_pmieducar_dispensa_disciplina();


--
-- Name: escola_serie_disciplina trigger_when_deleted_pmieducar_escola_serie_disciplina; Type: TRIGGER; Schema: pmieducar; Owner: -
--

CREATE TRIGGER trigger_when_deleted_pmieducar_escola_serie_disciplina AFTER DELETE ON pmieducar.escola_serie_disciplina FOR EACH ROW EXECUTE FUNCTION public.when_deleted_pmieducar_escola_serie_disciplina();


--
-- Name: escola_serie_disciplina update_escola_serie_disciplina_updated_at; Type: TRIGGER; Schema: pmieducar; Owner: -
--

CREATE TRIGGER update_escola_serie_disciplina_updated_at BEFORE UPDATE ON pmieducar.escola_serie_disciplina FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: aluno update_pmieducar_aluno; Type: TRIGGER; Schema: pmieducar; Owner: -
--

CREATE TRIGGER update_pmieducar_aluno BEFORE UPDATE ON pmieducar.aluno FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: curso update_pmieducar_curso; Type: TRIGGER; Schema: pmieducar; Owner: -
--

CREATE TRIGGER update_pmieducar_curso BEFORE UPDATE ON pmieducar.curso FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: disciplina_dependencia update_pmieducar_disciplina_dependencia; Type: TRIGGER; Schema: pmieducar; Owner: -
--

CREATE TRIGGER update_pmieducar_disciplina_dependencia BEFORE UPDATE ON pmieducar.disciplina_dependencia FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: dispensa_disciplina update_pmieducar_dispensa_disciplina; Type: TRIGGER; Schema: pmieducar; Owner: -
--

CREATE TRIGGER update_pmieducar_dispensa_disciplina BEFORE UPDATE ON pmieducar.dispensa_disciplina FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: escola update_pmieducar_escola; Type: TRIGGER; Schema: pmieducar; Owner: -
--

CREATE TRIGGER update_pmieducar_escola BEFORE UPDATE ON pmieducar.escola FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: escola_curso update_pmieducar_escola_curso; Type: TRIGGER; Schema: pmieducar; Owner: -
--

CREATE TRIGGER update_pmieducar_escola_curso BEFORE UPDATE ON pmieducar.escola_curso FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: escola_serie update_pmieducar_escola_serie; Type: TRIGGER; Schema: pmieducar; Owner: -
--

CREATE TRIGGER update_pmieducar_escola_serie BEFORE UPDATE ON pmieducar.escola_serie FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: matricula_ocorrencia_disciplinar update_pmieducar_matricula_ocorrencia_disciplinar; Type: TRIGGER; Schema: pmieducar; Owner: -
--

CREATE TRIGGER update_pmieducar_matricula_ocorrencia_disciplinar BEFORE UPDATE ON pmieducar.matricula_ocorrencia_disciplinar FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: serie update_pmieducar_serie; Type: TRIGGER; Schema: pmieducar; Owner: -
--

CREATE TRIGGER update_pmieducar_serie BEFORE UPDATE ON pmieducar.serie FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: servidor update_pmieducar_servidor; Type: TRIGGER; Schema: pmieducar; Owner: -
--

CREATE TRIGGER update_pmieducar_servidor BEFORE UPDATE ON pmieducar.servidor FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: turma update_pmieducar_turma; Type: TRIGGER; Schema: pmieducar; Owner: -
--

CREATE TRIGGER update_pmieducar_turma BEFORE UPDATE ON pmieducar.turma FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: fisica cadastro_fisica_povo_indigena_educacenso_id_foreign; Type: FK CONSTRAINT; Schema: cadastro; Owner: -
--

ALTER TABLE ONLY cadastro.fisica
    ADD CONSTRAINT cadastro_fisica_povo_indigena_educacenso_id_foreign FOREIGN KEY (povo_indigena_educacenso_id) REFERENCES modules.povo_indigena_educacenso(id);


--
-- Name: fisica cadastro_fisica_ref_cod_religiao_foreign; Type: FK CONSTRAINT; Schema: cadastro; Owner: -
--

ALTER TABLE ONLY cadastro.fisica
    ADD CONSTRAINT cadastro_fisica_ref_cod_religiao_foreign FOREIGN KEY (ref_cod_religiao) REFERENCES pmieducar.religions(id);


--
-- Name: calendario_turma calendario_turma_calendario_dia_fk; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.calendario_turma
    ADD CONSTRAINT calendario_turma_calendario_dia_fk FOREIGN KEY (mes, dia, calendario_ano_letivo_id) REFERENCES pmieducar.calendario_dia(mes, dia, ref_cod_calendario_ano_letivo) ON DELETE CASCADE;


--
-- Name: componente_curricular_ano_escolar modules_componente_curricular_ano_escolar_componente_curricular; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.componente_curricular_ano_escolar
    ADD CONSTRAINT modules_componente_curricular_ano_escolar_componente_curricular FOREIGN KEY (componente_curricular_id) REFERENCES modules.componente_curricular(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: componente_curricular_turma modules_componente_curricular_turma_componente_curricular_id_fo; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.componente_curricular_turma
    ADD CONSTRAINT modules_componente_curricular_turma_componente_curricular_id_fo FOREIGN KEY (componente_curricular_id) REFERENCES modules.componente_curricular(id) ON DELETE RESTRICT;


--
-- Name: componente_curricular_turma modules_componente_curricular_turma_turma_id_foreign; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.componente_curricular_turma
    ADD CONSTRAINT modules_componente_curricular_turma_turma_id_foreign FOREIGN KEY (turma_id) REFERENCES pmieducar.turma(cod_turma) ON DELETE CASCADE;


--
-- Name: config_movimento_geral modules_config_movimento_geral_ref_cod_serie_foreign; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.config_movimento_geral
    ADD CONSTRAINT modules_config_movimento_geral_ref_cod_serie_foreign FOREIGN KEY (ref_cod_serie) REFERENCES pmieducar.serie(cod_serie);


--
-- Name: educacenso_cod_aluno modules_educacenso_cod_aluno_cod_aluno_foreign; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.educacenso_cod_aluno
    ADD CONSTRAINT modules_educacenso_cod_aluno_cod_aluno_foreign FOREIGN KEY (cod_aluno) REFERENCES pmieducar.aluno(cod_aluno) ON DELETE CASCADE;


--
-- Name: educacenso_cod_escola modules_educacenso_cod_escola_cod_escola_foreign; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.educacenso_cod_escola
    ADD CONSTRAINT modules_educacenso_cod_escola_cod_escola_foreign FOREIGN KEY (cod_escola) REFERENCES pmieducar.escola(cod_escola) ON DELETE CASCADE;


--
-- Name: educacenso_cod_turma modules_educacenso_cod_turma_cod_turma_foreign; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.educacenso_cod_turma
    ADD CONSTRAINT modules_educacenso_cod_turma_cod_turma_foreign FOREIGN KEY (cod_turma) REFERENCES pmieducar.turma(cod_turma) ON DELETE CASCADE;


--
-- Name: educacenso_matricula modules_educacenso_matricula_matricula_turma_id_foreign; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.educacenso_matricula
    ADD CONSTRAINT modules_educacenso_matricula_matricula_turma_id_foreign FOREIGN KEY (matricula_turma_id) REFERENCES pmieducar.matricula_turma(id);


--
-- Name: etapas_curso_educacenso modules_etapas_curso_educacenso_curso_id_foreign; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.etapas_curso_educacenso
    ADD CONSTRAINT modules_etapas_curso_educacenso_curso_id_foreign FOREIGN KEY (curso_id) REFERENCES pmieducar.curso(cod_curso);


--
-- Name: etapas_curso_educacenso modules_etapas_curso_educacenso_etapa_id_foreign; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.etapas_curso_educacenso
    ADD CONSTRAINT modules_etapas_curso_educacenso_etapa_id_foreign FOREIGN KEY (etapa_id) REFERENCES modules.etapas_educacenso(id);


--
-- Name: falta_componente_curricular modules_falta_componente_curricular_falta_aluno_id_foreign; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.falta_componente_curricular
    ADD CONSTRAINT modules_falta_componente_curricular_falta_aluno_id_foreign FOREIGN KEY (falta_aluno_id) REFERENCES modules.falta_aluno(id) ON DELETE CASCADE;


--
-- Name: falta_geral modules_falta_geral_falta_aluno_id_foreign; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.falta_geral
    ADD CONSTRAINT modules_falta_geral_falta_aluno_id_foreign FOREIGN KEY (falta_aluno_id) REFERENCES modules.falta_aluno(id) ON DELETE CASCADE;


--
-- Name: ficha_medica_aluno modules_ficha_medica_aluno_ref_cod_aluno_foreign; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.ficha_medica_aluno
    ADD CONSTRAINT modules_ficha_medica_aluno_ref_cod_aluno_foreign FOREIGN KEY (ref_cod_aluno) REFERENCES pmieducar.aluno(cod_aluno) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: media_geral modules_media_geral_nota_aluno_id_foreign; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.media_geral
    ADD CONSTRAINT modules_media_geral_nota_aluno_id_foreign FOREIGN KEY (nota_aluno_id) REFERENCES modules.nota_aluno(id) ON DELETE CASCADE;


--
-- Name: moradia_aluno modules_moradia_aluno_ref_cod_aluno_foreign; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.moradia_aluno
    ADD CONSTRAINT modules_moradia_aluno_ref_cod_aluno_foreign FOREIGN KEY (ref_cod_aluno) REFERENCES pmieducar.aluno(cod_aluno) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: nota_componente_curricular_media modules_nota_componente_curricular_media_nota_aluno_id_foreign; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.nota_componente_curricular_media
    ADD CONSTRAINT modules_nota_componente_curricular_media_nota_aluno_id_foreign FOREIGN KEY (nota_aluno_id) REFERENCES modules.nota_aluno(id) ON DELETE CASCADE;


--
-- Name: nota_componente_curricular modules_nota_componente_curricular_nota_aluno_id_foreign; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.nota_componente_curricular
    ADD CONSTRAINT modules_nota_componente_curricular_nota_aluno_id_foreign FOREIGN KEY (nota_aluno_id) REFERENCES modules.nota_aluno(id) ON DELETE CASCADE;


--
-- Name: nota_exame modules_nota_exame_ref_cod_matricula_foreign; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.nota_exame
    ADD CONSTRAINT modules_nota_exame_ref_cod_matricula_foreign FOREIGN KEY (ref_cod_matricula) REFERENCES pmieducar.matricula(cod_matricula) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: nota_geral modules_nota_geral_nota_aluno_id_foreign; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.nota_geral
    ADD CONSTRAINT modules_nota_geral_nota_aluno_id_foreign FOREIGN KEY (nota_aluno_id) REFERENCES modules.nota_aluno(id) ON DELETE CASCADE;


--
-- Name: parecer_componente_curricular modules_parecer_componente_curricular_parecer_aluno_id_foreign; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.parecer_componente_curricular
    ADD CONSTRAINT modules_parecer_componente_curricular_parecer_aluno_id_foreign FOREIGN KEY (parecer_aluno_id) REFERENCES modules.parecer_aluno(id) ON DELETE CASCADE;


--
-- Name: parecer_geral modules_parecer_geral_parecer_aluno_id_foreign; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.parecer_geral
    ADD CONSTRAINT modules_parecer_geral_parecer_aluno_id_foreign FOREIGN KEY (parecer_aluno_id) REFERENCES modules.parecer_aluno(id) ON DELETE CASCADE;


--
-- Name: professor_turma_disciplina modules_professor_turma_disciplina_componente_curricular_id_for; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.professor_turma_disciplina
    ADD CONSTRAINT modules_professor_turma_disciplina_componente_curricular_id_for FOREIGN KEY (componente_curricular_id) REFERENCES modules.componente_curricular(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: professor_turma_disciplina modules_professor_turma_disciplina_professor_turma_id_foreign; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.professor_turma_disciplina
    ADD CONSTRAINT modules_professor_turma_disciplina_professor_turma_id_foreign FOREIGN KEY (professor_turma_id) REFERENCES modules.professor_turma(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: professor_turma modules_professor_turma_servidor_id_instituicao_id_foreign; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.professor_turma
    ADD CONSTRAINT modules_professor_turma_servidor_id_instituicao_id_foreign FOREIGN KEY (servidor_id, instituicao_id) REFERENCES pmieducar.servidor(cod_servidor, ref_cod_instituicao) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: professor_turma modules_professor_turma_turma_id_foreign; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.professor_turma
    ADD CONSTRAINT modules_professor_turma_turma_id_foreign FOREIGN KEY (turma_id) REFERENCES pmieducar.turma(cod_turma) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: professor_turma modules_professor_turma_turno_id_foreign; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.professor_turma
    ADD CONSTRAINT modules_professor_turma_turno_id_foreign FOREIGN KEY (turno_id) REFERENCES pmieducar.turma_turno(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: regra_avaliacao modules_regra_avaliacao_formula_media_id_instituicao_id_foreign; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.regra_avaliacao
    ADD CONSTRAINT modules_regra_avaliacao_formula_media_id_instituicao_id_foreign FOREIGN KEY (formula_media_id, instituicao_id) REFERENCES modules.formula_media(id, instituicao_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: regra_avaliacao modules_regra_avaliacao_formula_recuperacao_id_instituicao_id_f; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.regra_avaliacao
    ADD CONSTRAINT modules_regra_avaliacao_formula_recuperacao_id_instituicao_id_f FOREIGN KEY (formula_recuperacao_id, instituicao_id) REFERENCES modules.formula_media(id, instituicao_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: regra_avaliacao_recuperacao modules_regra_avaliacao_recuperacao_regra_avaliacao_id_foreign; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.regra_avaliacao_recuperacao
    ADD CONSTRAINT modules_regra_avaliacao_recuperacao_regra_avaliacao_id_foreign FOREIGN KEY (regra_avaliacao_id) REFERENCES modules.regra_avaliacao(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: regra_avaliacao modules_regra_avaliacao_regra_diferenciada_id_foreign; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.regra_avaliacao
    ADD CONSTRAINT modules_regra_avaliacao_regra_diferenciada_id_foreign FOREIGN KEY (regra_diferenciada_id) REFERENCES modules.regra_avaliacao(id);


--
-- Name: regra_avaliacao_serie_ano modules_regra_avaliacao_serie_ano_regra_avaliacao_diferenciada_; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.regra_avaliacao_serie_ano
    ADD CONSTRAINT modules_regra_avaliacao_serie_ano_regra_avaliacao_diferenciada_ FOREIGN KEY (regra_avaliacao_diferenciada_id) REFERENCES modules.regra_avaliacao(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: regra_avaliacao_serie_ano modules_regra_avaliacao_serie_ano_regra_avaliacao_id_foreign; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.regra_avaliacao_serie_ano
    ADD CONSTRAINT modules_regra_avaliacao_serie_ano_regra_avaliacao_id_foreign FOREIGN KEY (regra_avaliacao_id) REFERENCES modules.regra_avaliacao(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: regra_avaliacao_serie_ano modules_regra_avaliacao_serie_ano_serie_id_foreign; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.regra_avaliacao_serie_ano
    ADD CONSTRAINT modules_regra_avaliacao_serie_ano_serie_id_foreign FOREIGN KEY (serie_id) REFERENCES pmieducar.serie(cod_serie) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: regra_avaliacao modules_regra_avaliacao_tabela_arredondamento_id_instituicao_id; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.regra_avaliacao
    ADD CONSTRAINT modules_regra_avaliacao_tabela_arredondamento_id_instituicao_id FOREIGN KEY (tabela_arredondamento_id, instituicao_id) REFERENCES modules.tabela_arredondamento(id, instituicao_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: tabela_arredondamento_valor modules_tabela_arredondamento_valor_tabela_arredondamento_id_fo; Type: FK CONSTRAINT; Schema: modules; Owner: -
--

ALTER TABLE ONLY modules.tabela_arredondamento_valor
    ADD CONSTRAINT modules_tabela_arredondamento_valor_tabela_arredondamento_id_fo FOREIGN KEY (tabela_arredondamento_id) REFERENCES modules.tabela_arredondamento(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: aluno_historico_altura_peso aluno_historico_altura_peso_ref_cod_aluno_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.aluno_historico_altura_peso
    ADD CONSTRAINT aluno_historico_altura_peso_ref_cod_aluno_foreign FOREIGN KEY (ref_cod_aluno) REFERENCES pmieducar.aluno(cod_aluno);


--
-- Name: ano_letivo_modulo ano_letivo_modulo_escola_ano_letivo_id_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.ano_letivo_modulo
    ADD CONSTRAINT ano_letivo_modulo_escola_ano_letivo_id_foreign FOREIGN KEY (escola_ano_letivo_id) REFERENCES pmieducar.escola_ano_letivo(id) ON DELETE CASCADE;


--
-- Name: ano_letivo_modulo ano_letivo_modulo_ref_ref_cod_escola_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.ano_letivo_modulo
    ADD CONSTRAINT ano_letivo_modulo_ref_ref_cod_escola_foreign FOREIGN KEY (ref_ref_cod_escola) REFERENCES pmieducar.escola(cod_escola);


--
-- Name: calendario_dia_anotacao calendario_dia_anotacao_ref_ref_cod_calendario_ano_letivo_fkey; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.calendario_dia_anotacao
    ADD CONSTRAINT calendario_dia_anotacao_ref_ref_cod_calendario_ano_letivo_fkey FOREIGN KEY (ref_ref_cod_calendario_ano_letivo, ref_dia, ref_mes) REFERENCES pmieducar.calendario_dia(ref_cod_calendario_ano_letivo, dia, mes) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: abandono_tipo pmieducar_abandono_tipo_ref_cod_instituicao_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.abandono_tipo
    ADD CONSTRAINT pmieducar_abandono_tipo_ref_cod_instituicao_foreign FOREIGN KEY (ref_cod_instituicao) REFERENCES pmieducar.instituicao(cod_instituicao);


--
-- Name: aluno_aluno_beneficio pmieducar_aluno_aluno_beneficio_aluno_beneficio_id_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.aluno_aluno_beneficio
    ADD CONSTRAINT pmieducar_aluno_aluno_beneficio_aluno_beneficio_id_foreign FOREIGN KEY (aluno_beneficio_id) REFERENCES pmieducar.aluno_beneficio(cod_aluno_beneficio);


--
-- Name: aluno_aluno_beneficio pmieducar_aluno_aluno_beneficio_aluno_id_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.aluno_aluno_beneficio
    ADD CONSTRAINT pmieducar_aluno_aluno_beneficio_aluno_id_foreign FOREIGN KEY (aluno_id) REFERENCES pmieducar.aluno(cod_aluno);


--
-- Name: ano_letivo_modulo pmieducar_ano_letivo_modulo_ref_cod_modulo_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.ano_letivo_modulo
    ADD CONSTRAINT pmieducar_ano_letivo_modulo_ref_cod_modulo_foreign FOREIGN KEY (ref_cod_modulo) REFERENCES pmieducar.modulo(cod_modulo) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: ano_letivo_modulo pmieducar_ano_letivo_modulo_ref_ref_cod_escola_ref_ano_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.ano_letivo_modulo
    ADD CONSTRAINT pmieducar_ano_letivo_modulo_ref_ref_cod_escola_ref_ano_foreign FOREIGN KEY (ref_ref_cod_escola, ref_ano) REFERENCES pmieducar.escola_ano_letivo(ref_cod_escola, ano) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: bloqueio_ano_letivo pmieducar_bloqueio_ano_letivo_ref_cod_instituicao_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.bloqueio_ano_letivo
    ADD CONSTRAINT pmieducar_bloqueio_ano_letivo_ref_cod_instituicao_foreign FOREIGN KEY (ref_cod_instituicao) REFERENCES pmieducar.instituicao(cod_instituicao);


--
-- Name: bloqueio_lancamento_faltas_notas pmieducar_bloqueio_lancamento_faltas_notas_ref_cod_escola_forei; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.bloqueio_lancamento_faltas_notas
    ADD CONSTRAINT pmieducar_bloqueio_lancamento_faltas_notas_ref_cod_escola_forei FOREIGN KEY (ref_cod_escola) REFERENCES pmieducar.escola(cod_escola) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: busca_ativa pmieducar_busca_ativa_ref_cod_matricula_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.busca_ativa
    ADD CONSTRAINT pmieducar_busca_ativa_ref_cod_matricula_foreign FOREIGN KEY (ref_cod_matricula) REFERENCES pmieducar.matricula(cod_matricula);


--
-- Name: calendario_ano_letivo pmieducar_calendario_ano_letivo_ref_cod_escola_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.calendario_ano_letivo
    ADD CONSTRAINT pmieducar_calendario_ano_letivo_ref_cod_escola_foreign FOREIGN KEY (ref_cod_escola) REFERENCES pmieducar.escola(cod_escola) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: calendario_dia_anotacao pmieducar_calendario_dia_anotacao_ref_cod_calendario_anotacao_f; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.calendario_dia_anotacao
    ADD CONSTRAINT pmieducar_calendario_dia_anotacao_ref_cod_calendario_anotacao_f FOREIGN KEY (ref_cod_calendario_anotacao) REFERENCES pmieducar.calendario_anotacao(cod_calendario_anotacao) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: calendario_dia_motivo pmieducar_calendario_dia_motivo_ref_cod_escola_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.calendario_dia_motivo
    ADD CONSTRAINT pmieducar_calendario_dia_motivo_ref_cod_escola_foreign FOREIGN KEY (ref_cod_escola) REFERENCES pmieducar.escola(cod_escola) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: calendario_dia pmieducar_calendario_dia_ref_cod_calendario_ano_letivo_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.calendario_dia
    ADD CONSTRAINT pmieducar_calendario_dia_ref_cod_calendario_ano_letivo_foreign FOREIGN KEY (ref_cod_calendario_ano_letivo) REFERENCES pmieducar.calendario_ano_letivo(cod_calendario_ano_letivo);


--
-- Name: calendario_dia pmieducar_calendario_dia_ref_cod_calendario_dia_motivo_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.calendario_dia
    ADD CONSTRAINT pmieducar_calendario_dia_ref_cod_calendario_dia_motivo_foreign FOREIGN KEY (ref_cod_calendario_dia_motivo) REFERENCES pmieducar.calendario_dia_motivo(cod_calendario_dia_motivo);


--
-- Name: curso pmieducar_curso_ref_cod_instituicao_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.curso
    ADD CONSTRAINT pmieducar_curso_ref_cod_instituicao_foreign FOREIGN KEY (ref_cod_instituicao) REFERENCES pmieducar.instituicao(cod_instituicao) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: curso pmieducar_curso_ref_cod_nivel_ensino_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.curso
    ADD CONSTRAINT pmieducar_curso_ref_cod_nivel_ensino_foreign FOREIGN KEY (ref_cod_nivel_ensino) REFERENCES pmieducar.nivel_ensino(cod_nivel_ensino) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: curso pmieducar_curso_ref_cod_tipo_ensino_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.curso
    ADD CONSTRAINT pmieducar_curso_ref_cod_tipo_ensino_foreign FOREIGN KEY (ref_cod_tipo_ensino) REFERENCES pmieducar.tipo_ensino(cod_tipo_ensino) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: curso pmieducar_curso_ref_cod_tipo_regime_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.curso
    ADD CONSTRAINT pmieducar_curso_ref_cod_tipo_regime_foreign FOREIGN KEY (ref_cod_tipo_regime) REFERENCES pmieducar.tipo_regime(cod_tipo_regime) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: disciplina_dependencia pmieducar_disciplina_dependencia_ref_cod_matricula_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.disciplina_dependencia
    ADD CONSTRAINT pmieducar_disciplina_dependencia_ref_cod_matricula_foreign FOREIGN KEY (ref_cod_matricula) REFERENCES pmieducar.matricula(cod_matricula) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: disciplina_dependencia pmieducar_disciplina_dependencia_ref_cod_serie_ref_cod_escola_r; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.disciplina_dependencia
    ADD CONSTRAINT pmieducar_disciplina_dependencia_ref_cod_serie_ref_cod_escola_r FOREIGN KEY (ref_cod_serie, ref_cod_escola, ref_cod_disciplina) REFERENCES pmieducar.escola_serie_disciplina(ref_ref_cod_serie, ref_ref_cod_escola, ref_cod_disciplina) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: disciplina_serie pmieducar_disciplina_serie_ref_cod_serie_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.disciplina_serie
    ADD CONSTRAINT pmieducar_disciplina_serie_ref_cod_serie_foreign FOREIGN KEY (ref_cod_serie) REFERENCES pmieducar.serie(cod_serie) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: dispensa_disciplina pmieducar_dispensa_disciplina_ref_cod_matricula_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.dispensa_disciplina
    ADD CONSTRAINT pmieducar_dispensa_disciplina_ref_cod_matricula_foreign FOREIGN KEY (ref_cod_matricula) REFERENCES pmieducar.matricula(cod_matricula) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: dispensa_disciplina pmieducar_dispensa_disciplina_ref_cod_tipo_dispensa_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.dispensa_disciplina
    ADD CONSTRAINT pmieducar_dispensa_disciplina_ref_cod_tipo_dispensa_foreign FOREIGN KEY (ref_cod_tipo_dispensa) REFERENCES pmieducar.tipo_dispensa(cod_tipo_dispensa) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: dispensa_etapa pmieducar_dispensa_etapa_ref_cod_dispensa_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.dispensa_etapa
    ADD CONSTRAINT pmieducar_dispensa_etapa_ref_cod_dispensa_foreign FOREIGN KEY (ref_cod_dispensa) REFERENCES pmieducar.dispensa_disciplina(cod_dispensa);


--
-- Name: escola_ano_letivo pmieducar_escola_ano_letivo_ref_cod_escola_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.escola_ano_letivo
    ADD CONSTRAINT pmieducar_escola_ano_letivo_ref_cod_escola_foreign FOREIGN KEY (ref_cod_escola) REFERENCES pmieducar.escola(cod_escola) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: escola pmieducar_escola_codigo_ies_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.escola
    ADD CONSTRAINT pmieducar_escola_codigo_ies_foreign FOREIGN KEY (codigo_ies) REFERENCES modules.educacenso_ies(id);


--
-- Name: escola_curso pmieducar_escola_curso_ref_cod_curso_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.escola_curso
    ADD CONSTRAINT pmieducar_escola_curso_ref_cod_curso_foreign FOREIGN KEY (ref_cod_curso) REFERENCES pmieducar.curso(cod_curso) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: escola_curso pmieducar_escola_curso_ref_cod_escola_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.escola_curso
    ADD CONSTRAINT pmieducar_escola_curso_ref_cod_escola_foreign FOREIGN KEY (ref_cod_escola) REFERENCES pmieducar.escola(cod_escola) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: escola_localizacao pmieducar_escola_localizacao_ref_cod_instituicao_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.escola_localizacao
    ADD CONSTRAINT pmieducar_escola_localizacao_ref_cod_instituicao_foreign FOREIGN KEY (ref_cod_instituicao) REFERENCES pmieducar.instituicao(cod_instituicao) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: escola pmieducar_escola_ref_cod_instituicao_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.escola
    ADD CONSTRAINT pmieducar_escola_ref_cod_instituicao_foreign FOREIGN KEY (ref_cod_instituicao) REFERENCES pmieducar.instituicao(cod_instituicao) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: escola_serie_disciplina pmieducar_escola_serie_disciplina_ref_cod_disciplina_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.escola_serie_disciplina
    ADD CONSTRAINT pmieducar_escola_serie_disciplina_ref_cod_disciplina_foreign FOREIGN KEY (ref_cod_disciplina) REFERENCES modules.componente_curricular(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: escola_serie_disciplina pmieducar_escola_serie_disciplina_ref_ref_cod_escola_ref_ref_co; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.escola_serie_disciplina
    ADD CONSTRAINT pmieducar_escola_serie_disciplina_ref_ref_cod_escola_ref_ref_co FOREIGN KEY (ref_ref_cod_escola, ref_ref_cod_serie) REFERENCES pmieducar.escola_serie(ref_cod_escola, ref_cod_serie) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: escola_serie pmieducar_escola_serie_ref_cod_escola_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.escola_serie
    ADD CONSTRAINT pmieducar_escola_serie_ref_cod_escola_foreign FOREIGN KEY (ref_cod_escola) REFERENCES pmieducar.escola(cod_escola) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: escola_serie pmieducar_escola_serie_ref_cod_serie_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.escola_serie
    ADD CONSTRAINT pmieducar_escola_serie_ref_cod_serie_foreign FOREIGN KEY (ref_cod_serie) REFERENCES pmieducar.serie(cod_serie) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: escola_usuario pmieducar_escola_usuario_ref_cod_escola_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.escola_usuario
    ADD CONSTRAINT pmieducar_escola_usuario_ref_cod_escola_foreign FOREIGN KEY (ref_cod_escola) REFERENCES pmieducar.escola(cod_escola);


--
-- Name: escola_usuario pmieducar_escola_usuario_ref_cod_usuario_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.escola_usuario
    ADD CONSTRAINT pmieducar_escola_usuario_ref_cod_usuario_foreign FOREIGN KEY (ref_cod_usuario) REFERENCES pmieducar.usuario(cod_usuario);


--
-- Name: falta_atraso_compensado pmieducar_falta_atraso_compensado_ref_cod_escola_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.falta_atraso_compensado
    ADD CONSTRAINT pmieducar_falta_atraso_compensado_ref_cod_escola_foreign FOREIGN KEY (ref_cod_escola) REFERENCES pmieducar.escola(cod_escola) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: falta_atraso_compensado pmieducar_falta_atraso_compensado_ref_cod_servidor_ref_ref_cod_; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.falta_atraso_compensado
    ADD CONSTRAINT pmieducar_falta_atraso_compensado_ref_cod_servidor_ref_ref_cod_ FOREIGN KEY (ref_cod_servidor, ref_ref_cod_instituicao) REFERENCES pmieducar.servidor(cod_servidor, ref_cod_instituicao) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: falta_atraso pmieducar_falta_atraso_ref_cod_escola_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.falta_atraso
    ADD CONSTRAINT pmieducar_falta_atraso_ref_cod_escola_foreign FOREIGN KEY (ref_cod_escola) REFERENCES pmieducar.escola(cod_escola) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: falta_atraso pmieducar_falta_atraso_ref_cod_servidor_funcao_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.falta_atraso
    ADD CONSTRAINT pmieducar_falta_atraso_ref_cod_servidor_funcao_foreign FOREIGN KEY (ref_cod_servidor_funcao) REFERENCES pmieducar.servidor_funcao(cod_servidor_funcao);


--
-- Name: falta_atraso pmieducar_falta_atraso_ref_cod_servidor_ref_ref_cod_instituicao; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.falta_atraso
    ADD CONSTRAINT pmieducar_falta_atraso_ref_cod_servidor_ref_ref_cod_instituicao FOREIGN KEY (ref_cod_servidor, ref_ref_cod_instituicao) REFERENCES pmieducar.servidor(cod_servidor, ref_cod_instituicao) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: funcao pmieducar_funcao_ref_cod_instituicao_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.funcao
    ADD CONSTRAINT pmieducar_funcao_ref_cod_instituicao_foreign FOREIGN KEY (ref_cod_instituicao) REFERENCES pmieducar.instituicao(cod_instituicao) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: historico_disciplinas pmieducar_historico_disciplinas_ref_ref_cod_aluno_ref_sequencia; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.historico_disciplinas
    ADD CONSTRAINT pmieducar_historico_disciplinas_ref_ref_cod_aluno_ref_sequencia FOREIGN KEY (ref_ref_cod_aluno, ref_sequencial) REFERENCES pmieducar.historico_escolar(ref_cod_aluno, sequencial) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: historico_escolar pmieducar_historico_escolar_historico_grade_curso_id_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.historico_escolar
    ADD CONSTRAINT pmieducar_historico_escolar_historico_grade_curso_id_foreign FOREIGN KEY (historico_grade_curso_id) REFERENCES pmieducar.historico_grade_curso(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: historico_escolar pmieducar_historico_escolar_ref_cod_aluno_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.historico_escolar
    ADD CONSTRAINT pmieducar_historico_escolar_ref_cod_aluno_foreign FOREIGN KEY (ref_cod_aluno) REFERENCES pmieducar.aluno(cod_aluno) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: historico_escolar pmieducar_historico_escolar_ref_cod_escola_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.historico_escolar
    ADD CONSTRAINT pmieducar_historico_escolar_ref_cod_escola_foreign FOREIGN KEY (ref_cod_escola) REFERENCES pmieducar.escola(cod_escola);


--
-- Name: instituicao_documentacao pmieducar_instituicao_documentacao_instituicao_id_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.instituicao_documentacao
    ADD CONSTRAINT pmieducar_instituicao_documentacao_instituicao_id_foreign FOREIGN KEY (instituicao_id) REFERENCES pmieducar.instituicao(cod_instituicao) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: matricula_ocorrencia_disciplinar pmieducar_matricula_ocorrencia_disciplinar_ref_cod_matricula_fo; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.matricula_ocorrencia_disciplinar
    ADD CONSTRAINT pmieducar_matricula_ocorrencia_disciplinar_ref_cod_matricula_fo FOREIGN KEY (ref_cod_matricula) REFERENCES pmieducar.matricula(cod_matricula) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: matricula_ocorrencia_disciplinar pmieducar_matricula_ocorrencia_disciplinar_ref_cod_tipo_ocorren; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.matricula_ocorrencia_disciplinar
    ADD CONSTRAINT pmieducar_matricula_ocorrencia_disciplinar_ref_cod_tipo_ocorren FOREIGN KEY (ref_cod_tipo_ocorrencia_disciplinar) REFERENCES pmieducar.tipo_ocorrencia_disciplinar(cod_tipo_ocorrencia_disciplinar) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: matricula pmieducar_matricula_ref_cod_abandono_tipo_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.matricula
    ADD CONSTRAINT pmieducar_matricula_ref_cod_abandono_tipo_foreign FOREIGN KEY (ref_cod_abandono_tipo) REFERENCES pmieducar.abandono_tipo(cod_abandono_tipo);


--
-- Name: matricula pmieducar_matricula_ref_cod_aluno_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.matricula
    ADD CONSTRAINT pmieducar_matricula_ref_cod_aluno_foreign FOREIGN KEY (ref_cod_aluno) REFERENCES pmieducar.aluno(cod_aluno) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: matricula pmieducar_matricula_ref_cod_curso_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.matricula
    ADD CONSTRAINT pmieducar_matricula_ref_cod_curso_foreign FOREIGN KEY (ref_cod_curso) REFERENCES pmieducar.curso(cod_curso) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: matricula pmieducar_matricula_ref_ref_cod_escola_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.matricula
    ADD CONSTRAINT pmieducar_matricula_ref_ref_cod_escola_foreign FOREIGN KEY (ref_ref_cod_escola) REFERENCES pmieducar.escola(cod_escola) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: matricula pmieducar_matricula_ref_ref_cod_serie_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.matricula
    ADD CONSTRAINT pmieducar_matricula_ref_ref_cod_serie_foreign FOREIGN KEY (ref_ref_cod_serie) REFERENCES pmieducar.serie(cod_serie) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: matricula_turma pmieducar_matricula_turma_ref_cod_matricula_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.matricula_turma
    ADD CONSTRAINT pmieducar_matricula_turma_ref_cod_matricula_foreign FOREIGN KEY (ref_cod_matricula) REFERENCES pmieducar.matricula(cod_matricula) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: matricula_turma pmieducar_matricula_turma_ref_cod_turma_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.matricula_turma
    ADD CONSTRAINT pmieducar_matricula_turma_ref_cod_turma_foreign FOREIGN KEY (ref_cod_turma) REFERENCES pmieducar.turma(cod_turma) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: menu_tipo_usuario pmieducar_menu_tipo_usuario_ref_cod_tipo_usuario_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.menu_tipo_usuario
    ADD CONSTRAINT pmieducar_menu_tipo_usuario_ref_cod_tipo_usuario_foreign FOREIGN KEY (ref_cod_tipo_usuario) REFERENCES pmieducar.tipo_usuario(cod_tipo_usuario) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: modulo pmieducar_modulo_ref_cod_instituicao_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.modulo
    ADD CONSTRAINT pmieducar_modulo_ref_cod_instituicao_foreign FOREIGN KEY (ref_cod_instituicao) REFERENCES pmieducar.instituicao(cod_instituicao) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: motivo_afastamento pmieducar_motivo_afastamento_ref_cod_instituicao_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.motivo_afastamento
    ADD CONSTRAINT pmieducar_motivo_afastamento_ref_cod_instituicao_foreign FOREIGN KEY (ref_cod_instituicao) REFERENCES pmieducar.instituicao(cod_instituicao) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: nivel_ensino pmieducar_nivel_ensino_ref_cod_instituicao_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.nivel_ensino
    ADD CONSTRAINT pmieducar_nivel_ensino_ref_cod_instituicao_foreign FOREIGN KEY (ref_cod_instituicao) REFERENCES pmieducar.instituicao(cod_instituicao) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: projeto_aluno pmieducar_projeto_aluno_ref_cod_aluno_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.projeto_aluno
    ADD CONSTRAINT pmieducar_projeto_aluno_ref_cod_aluno_foreign FOREIGN KEY (ref_cod_aluno) REFERENCES pmieducar.aluno(cod_aluno);


--
-- Name: projeto_aluno pmieducar_projeto_aluno_ref_cod_projeto_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.projeto_aluno
    ADD CONSTRAINT pmieducar_projeto_aluno_ref_cod_projeto_foreign FOREIGN KEY (ref_cod_projeto) REFERENCES pmieducar.projeto(cod_projeto);


--
-- Name: quadro_horario_horarios_aux pmieducar_quadro_horario_horarios_aux_ref_cod_quadro_horario_fo; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.quadro_horario_horarios_aux
    ADD CONSTRAINT pmieducar_quadro_horario_horarios_aux_ref_cod_quadro_horario_fo FOREIGN KEY (ref_cod_quadro_horario) REFERENCES pmieducar.quadro_horario(cod_quadro_horario) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: quadro_horario_horarios_aux pmieducar_quadro_horario_horarios_aux_ref_cod_serie_ref_cod_esc; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.quadro_horario_horarios_aux
    ADD CONSTRAINT pmieducar_quadro_horario_horarios_aux_ref_cod_serie_ref_cod_esc FOREIGN KEY (ref_cod_serie, ref_cod_escola, ref_cod_disciplina) REFERENCES pmieducar.escola_serie_disciplina(ref_ref_cod_serie, ref_ref_cod_escola, ref_cod_disciplina) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: quadro_horario_horarios_aux pmieducar_quadro_horario_horarios_aux_ref_servidor_ref_cod_inst; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.quadro_horario_horarios_aux
    ADD CONSTRAINT pmieducar_quadro_horario_horarios_aux_ref_servidor_ref_cod_inst FOREIGN KEY (ref_servidor, ref_cod_instituicao_servidor) REFERENCES pmieducar.servidor(cod_servidor, ref_cod_instituicao) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: quadro_horario_horarios pmieducar_quadro_horario_horarios_ref_cod_quadro_horario_foreig; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.quadro_horario_horarios
    ADD CONSTRAINT pmieducar_quadro_horario_horarios_ref_cod_quadro_horario_foreig FOREIGN KEY (ref_cod_quadro_horario) REFERENCES pmieducar.quadro_horario(cod_quadro_horario) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: quadro_horario_horarios pmieducar_quadro_horario_horarios_ref_servidor_ref_cod_institui; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.quadro_horario_horarios
    ADD CONSTRAINT pmieducar_quadro_horario_horarios_ref_servidor_ref_cod_institui FOREIGN KEY (ref_servidor, ref_cod_instituicao_servidor) REFERENCES pmieducar.servidor(cod_servidor, ref_cod_instituicao) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: quadro_horario_horarios pmieducar_quadro_horario_horarios_ref_servidor_substituto_ref_c; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.quadro_horario_horarios
    ADD CONSTRAINT pmieducar_quadro_horario_horarios_ref_servidor_substituto_ref_c FOREIGN KEY (ref_servidor_substituto, ref_cod_instituicao_substituto) REFERENCES pmieducar.servidor(cod_servidor, ref_cod_instituicao) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: quadro_horario pmieducar_quadro_horario_ref_cod_turma_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.quadro_horario
    ADD CONSTRAINT pmieducar_quadro_horario_ref_cod_turma_foreign FOREIGN KEY (ref_cod_turma) REFERENCES pmieducar.turma(cod_turma) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: sequencia_serie pmieducar_sequencia_serie_ref_serie_destino_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.sequencia_serie
    ADD CONSTRAINT pmieducar_sequencia_serie_ref_serie_destino_foreign FOREIGN KEY (ref_serie_destino) REFERENCES pmieducar.serie(cod_serie) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: sequencia_serie pmieducar_sequencia_serie_ref_serie_origem_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.sequencia_serie
    ADD CONSTRAINT pmieducar_sequencia_serie_ref_serie_origem_foreign FOREIGN KEY (ref_serie_origem) REFERENCES pmieducar.serie(cod_serie) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: serie pmieducar_serie_ref_cod_curso_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.serie
    ADD CONSTRAINT pmieducar_serie_ref_cod_curso_foreign FOREIGN KEY (ref_cod_curso) REFERENCES pmieducar.curso(cod_curso) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: serie pmieducar_serie_regra_avaliacao_diferenciada_id_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.serie
    ADD CONSTRAINT pmieducar_serie_regra_avaliacao_diferenciada_id_foreign FOREIGN KEY (regra_avaliacao_diferenciada_id) REFERENCES modules.regra_avaliacao(id) ON DELETE RESTRICT;


--
-- Name: serie pmieducar_serie_regra_avaliacao_id_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.serie
    ADD CONSTRAINT pmieducar_serie_regra_avaliacao_id_foreign FOREIGN KEY (regra_avaliacao_id) REFERENCES modules.regra_avaliacao(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: servidor_afastamento pmieducar_servidor_afastamento_ref_cod_motivo_afastamento_forei; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.servidor_afastamento
    ADD CONSTRAINT pmieducar_servidor_afastamento_ref_cod_motivo_afastamento_forei FOREIGN KEY (ref_cod_motivo_afastamento) REFERENCES pmieducar.motivo_afastamento(cod_motivo_afastamento) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: servidor_afastamento pmieducar_servidor_afastamento_ref_cod_servidor_ref_ref_cod_ins; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.servidor_afastamento
    ADD CONSTRAINT pmieducar_servidor_afastamento_ref_cod_servidor_ref_ref_cod_ins FOREIGN KEY (ref_cod_servidor, ref_ref_cod_instituicao) REFERENCES pmieducar.servidor(cod_servidor, ref_cod_instituicao) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: servidor_alocacao pmieducar_servidor_alocacao_ref_cod_escola_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.servidor_alocacao
    ADD CONSTRAINT pmieducar_servidor_alocacao_ref_cod_escola_foreign FOREIGN KEY (ref_cod_escola) REFERENCES pmieducar.escola(cod_escola) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: servidor_alocacao pmieducar_servidor_alocacao_ref_cod_servidor_ref_ref_cod_instit; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.servidor_alocacao
    ADD CONSTRAINT pmieducar_servidor_alocacao_ref_cod_servidor_ref_ref_cod_instit FOREIGN KEY (ref_cod_servidor, ref_ref_cod_instituicao) REFERENCES pmieducar.servidor(cod_servidor, ref_cod_instituicao) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: servidor pmieducar_servidor_codigo_curso_superior_1_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.servidor
    ADD CONSTRAINT pmieducar_servidor_codigo_curso_superior_1_foreign FOREIGN KEY (codigo_curso_superior_1) REFERENCES modules.educacenso_curso_superior(id) ON DELETE SET NULL;


--
-- Name: servidor pmieducar_servidor_codigo_curso_superior_2_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.servidor
    ADD CONSTRAINT pmieducar_servidor_codigo_curso_superior_2_foreign FOREIGN KEY (codigo_curso_superior_2) REFERENCES modules.educacenso_curso_superior(id) ON DELETE SET NULL;


--
-- Name: servidor pmieducar_servidor_codigo_curso_superior_3_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.servidor
    ADD CONSTRAINT pmieducar_servidor_codigo_curso_superior_3_foreign FOREIGN KEY (codigo_curso_superior_3) REFERENCES modules.educacenso_curso_superior(id) ON DELETE SET NULL;


--
-- Name: servidor_curso_ministra pmieducar_servidor_curso_ministra_ref_cod_curso_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.servidor_curso_ministra
    ADD CONSTRAINT pmieducar_servidor_curso_ministra_ref_cod_curso_foreign FOREIGN KEY (ref_cod_curso) REFERENCES pmieducar.curso(cod_curso) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: servidor_curso_ministra pmieducar_servidor_curso_ministra_ref_cod_servidor_ref_ref_cod_; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.servidor_curso_ministra
    ADD CONSTRAINT pmieducar_servidor_curso_ministra_ref_cod_servidor_ref_ref_cod_ FOREIGN KEY (ref_cod_servidor, ref_ref_cod_instituicao) REFERENCES pmieducar.servidor(cod_servidor, ref_cod_instituicao) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: servidor_disciplina pmieducar_servidor_disciplina_ref_cod_disciplina_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.servidor_disciplina
    ADD CONSTRAINT pmieducar_servidor_disciplina_ref_cod_disciplina_foreign FOREIGN KEY (ref_cod_disciplina) REFERENCES modules.componente_curricular(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: servidor_disciplina pmieducar_servidor_disciplina_ref_cod_funcao_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.servidor_disciplina
    ADD CONSTRAINT pmieducar_servidor_disciplina_ref_cod_funcao_foreign FOREIGN KEY (ref_cod_funcao) REFERENCES pmieducar.servidor_funcao(cod_servidor_funcao);


--
-- Name: servidor_disciplina pmieducar_servidor_disciplina_ref_cod_servidor_ref_ref_cod_inst; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.servidor_disciplina
    ADD CONSTRAINT pmieducar_servidor_disciplina_ref_cod_servidor_ref_ref_cod_inst FOREIGN KEY (ref_cod_servidor, ref_ref_cod_instituicao) REFERENCES pmieducar.servidor(cod_servidor, ref_cod_instituicao) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: servidor_frequencia pmieducar_servidor_frequencia_registrado_por_usuario_id_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.servidor_frequencia
    ADD CONSTRAINT pmieducar_servidor_frequencia_registrado_por_usuario_id_foreign FOREIGN KEY (registrado_por_usuario_id) REFERENCES pmieducar.usuario(cod_usuario);


--
-- Name: servidor_funcao pmieducar_servidor_funcao_ref_cod_funcao_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.servidor_funcao
    ADD CONSTRAINT pmieducar_servidor_funcao_ref_cod_funcao_foreign FOREIGN KEY (ref_cod_funcao) REFERENCES pmieducar.funcao(cod_funcao) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: servidor_funcao pmieducar_servidor_funcao_ref_cod_servidor_ref_ref_cod_institui; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.servidor_funcao
    ADD CONSTRAINT pmieducar_servidor_funcao_ref_cod_servidor_ref_ref_cod_institui FOREIGN KEY (ref_cod_servidor, ref_ref_cod_instituicao) REFERENCES pmieducar.servidor(cod_servidor, ref_cod_instituicao) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: servidor pmieducar_servidor_instituicao_curso_superior_1_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.servidor
    ADD CONSTRAINT pmieducar_servidor_instituicao_curso_superior_1_foreign FOREIGN KEY (instituicao_curso_superior_1) REFERENCES modules.educacenso_ies(id);


--
-- Name: servidor pmieducar_servidor_instituicao_curso_superior_2_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.servidor
    ADD CONSTRAINT pmieducar_servidor_instituicao_curso_superior_2_foreign FOREIGN KEY (instituicao_curso_superior_2) REFERENCES modules.educacenso_ies(id);


--
-- Name: servidor pmieducar_servidor_instituicao_curso_superior_3_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.servidor
    ADD CONSTRAINT pmieducar_servidor_instituicao_curso_superior_3_foreign FOREIGN KEY (instituicao_curso_superior_3) REFERENCES modules.educacenso_ies(id);


--
-- Name: servidor pmieducar_servidor_ref_cod_instituicao_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.servidor
    ADD CONSTRAINT pmieducar_servidor_ref_cod_instituicao_foreign FOREIGN KEY (ref_cod_instituicao) REFERENCES pmieducar.instituicao(cod_instituicao) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: tipo_dispensa pmieducar_tipo_dispensa_ref_cod_instituicao_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.tipo_dispensa
    ADD CONSTRAINT pmieducar_tipo_dispensa_ref_cod_instituicao_foreign FOREIGN KEY (ref_cod_instituicao) REFERENCES pmieducar.instituicao(cod_instituicao) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: tipo_ensino pmieducar_tipo_ensino_ref_cod_instituicao_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.tipo_ensino
    ADD CONSTRAINT pmieducar_tipo_ensino_ref_cod_instituicao_foreign FOREIGN KEY (ref_cod_instituicao) REFERENCES pmieducar.instituicao(cod_instituicao) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: tipo_ocorrencia_disciplinar pmieducar_tipo_ocorrencia_disciplinar_ref_cod_instituicao_forei; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.tipo_ocorrencia_disciplinar
    ADD CONSTRAINT pmieducar_tipo_ocorrencia_disciplinar_ref_cod_instituicao_forei FOREIGN KEY (ref_cod_instituicao) REFERENCES pmieducar.instituicao(cod_instituicao) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: tipo_regime pmieducar_tipo_regime_ref_cod_instituicao_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.tipo_regime
    ADD CONSTRAINT pmieducar_tipo_regime_ref_cod_instituicao_foreign FOREIGN KEY (ref_cod_instituicao) REFERENCES pmieducar.instituicao(cod_instituicao) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: tipo_usuario pmieducar_tipo_usuario_ref_funcionario_cad_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.tipo_usuario
    ADD CONSTRAINT pmieducar_tipo_usuario_ref_funcionario_cad_foreign FOREIGN KEY (ref_funcionario_cad) REFERENCES portal.funcionario(ref_cod_pessoa_fj) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: tipo_usuario pmieducar_tipo_usuario_ref_funcionario_exc_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.tipo_usuario
    ADD CONSTRAINT pmieducar_tipo_usuario_ref_funcionario_exc_foreign FOREIGN KEY (ref_funcionario_exc) REFERENCES portal.funcionario(ref_cod_pessoa_fj) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: transferencia_solicitacao pmieducar_transferencia_solicitacao_ref_cod_matricula_entrada_f; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.transferencia_solicitacao
    ADD CONSTRAINT pmieducar_transferencia_solicitacao_ref_cod_matricula_entrada_f FOREIGN KEY (ref_cod_matricula_entrada) REFERENCES pmieducar.matricula(cod_matricula) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: transferencia_solicitacao pmieducar_transferencia_solicitacao_ref_cod_matricula_saida_for; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.transferencia_solicitacao
    ADD CONSTRAINT pmieducar_transferencia_solicitacao_ref_cod_matricula_saida_for FOREIGN KEY (ref_cod_matricula_saida) REFERENCES pmieducar.matricula(cod_matricula) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: transferencia_solicitacao pmieducar_transferencia_solicitacao_ref_cod_transferencia_tipo_; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.transferencia_solicitacao
    ADD CONSTRAINT pmieducar_transferencia_solicitacao_ref_cod_transferencia_tipo_ FOREIGN KEY (ref_cod_transferencia_tipo) REFERENCES pmieducar.transferencia_tipo(cod_transferencia_tipo) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: transferencia_tipo pmieducar_transferencia_tipo_ref_cod_instituicao_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.transferencia_tipo
    ADD CONSTRAINT pmieducar_transferencia_tipo_ref_cod_instituicao_foreign FOREIGN KEY (ref_cod_instituicao) REFERENCES pmieducar.instituicao(cod_instituicao) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: turma_modulo pmieducar_turma_modulo_ref_cod_modulo_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.turma_modulo
    ADD CONSTRAINT pmieducar_turma_modulo_ref_cod_modulo_foreign FOREIGN KEY (ref_cod_modulo) REFERENCES pmieducar.modulo(cod_modulo) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: turma_modulo pmieducar_turma_modulo_ref_cod_turma_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.turma_modulo
    ADD CONSTRAINT pmieducar_turma_modulo_ref_cod_turma_foreign FOREIGN KEY (ref_cod_turma) REFERENCES pmieducar.turma(cod_turma) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: turma pmieducar_turma_ref_cod_curso_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.turma
    ADD CONSTRAINT pmieducar_turma_ref_cod_curso_foreign FOREIGN KEY (ref_cod_curso) REFERENCES pmieducar.curso(cod_curso) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: turma pmieducar_turma_ref_cod_disciplina_dispensada_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.turma
    ADD CONSTRAINT pmieducar_turma_ref_cod_disciplina_dispensada_foreign FOREIGN KEY (ref_cod_disciplina_dispensada) REFERENCES modules.componente_curricular(id);


--
-- Name: turma pmieducar_turma_ref_cod_instituicao_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.turma
    ADD CONSTRAINT pmieducar_turma_ref_cod_instituicao_foreign FOREIGN KEY (ref_cod_instituicao) REFERENCES pmieducar.instituicao(cod_instituicao) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: turma pmieducar_turma_ref_cod_regente_ref_cod_instituicao_regente_for; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.turma
    ADD CONSTRAINT pmieducar_turma_ref_cod_regente_ref_cod_instituicao_regente_for FOREIGN KEY (ref_cod_regente, ref_cod_instituicao_regente) REFERENCES pmieducar.servidor(cod_servidor, ref_cod_instituicao) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: turma pmieducar_turma_ref_cod_turma_tipo_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.turma
    ADD CONSTRAINT pmieducar_turma_ref_cod_turma_tipo_foreign FOREIGN KEY (ref_cod_turma_tipo) REFERENCES pmieducar.turma_tipo(cod_turma_tipo) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: turma pmieducar_turma_ref_ref_cod_escola_ref_ref_cod_serie_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.turma
    ADD CONSTRAINT pmieducar_turma_ref_ref_cod_escola_ref_ref_cod_serie_foreign FOREIGN KEY (ref_ref_cod_escola, ref_ref_cod_serie) REFERENCES pmieducar.escola_serie(ref_cod_escola, ref_cod_serie) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: turma pmieducar_turma_ref_ref_cod_serie_mult_ref_ref_cod_escola_mult_; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.turma
    ADD CONSTRAINT pmieducar_turma_ref_ref_cod_serie_mult_ref_ref_cod_escola_mult_ FOREIGN KEY (ref_ref_cod_serie_mult, ref_ref_cod_escola_mult) REFERENCES pmieducar.escola_serie(ref_cod_serie, ref_cod_escola) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: turma_serie pmieducar_turma_serie_escola_id_serie_id_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.turma_serie
    ADD CONSTRAINT pmieducar_turma_serie_escola_id_serie_id_foreign FOREIGN KEY (escola_id, serie_id) REFERENCES pmieducar.escola_serie(ref_cod_escola, ref_cod_serie);


--
-- Name: turma_serie pmieducar_turma_serie_turma_id_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.turma_serie
    ADD CONSTRAINT pmieducar_turma_serie_turma_id_foreign FOREIGN KEY (turma_id) REFERENCES pmieducar.turma(cod_turma);


--
-- Name: turma pmieducar_turma_turma_turno_id_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.turma
    ADD CONSTRAINT pmieducar_turma_turma_turno_id_foreign FOREIGN KEY (turma_turno_id) REFERENCES pmieducar.turma_turno(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: usuario pmieducar_usuario_cod_usuario_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.usuario
    ADD CONSTRAINT pmieducar_usuario_cod_usuario_foreign FOREIGN KEY (cod_usuario) REFERENCES portal.funcionario(ref_cod_pessoa_fj) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: usuario pmieducar_usuario_ref_cod_instituicao_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.usuario
    ADD CONSTRAINT pmieducar_usuario_ref_cod_instituicao_foreign FOREIGN KEY (ref_cod_instituicao) REFERENCES pmieducar.instituicao(cod_instituicao) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: usuario pmieducar_usuario_ref_cod_tipo_usuario_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.usuario
    ADD CONSTRAINT pmieducar_usuario_ref_cod_tipo_usuario_foreign FOREIGN KEY (ref_cod_tipo_usuario) REFERENCES pmieducar.tipo_usuario(cod_tipo_usuario) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: usuario pmieducar_usuario_ref_funcionario_cad_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.usuario
    ADD CONSTRAINT pmieducar_usuario_ref_funcionario_cad_foreign FOREIGN KEY (ref_funcionario_cad) REFERENCES portal.funcionario(ref_cod_pessoa_fj) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: usuario pmieducar_usuario_ref_funcionario_exc_foreign; Type: FK CONSTRAINT; Schema: pmieducar; Owner: -
--

ALTER TABLE ONLY pmieducar.usuario
    ADD CONSTRAINT pmieducar_usuario_ref_funcionario_exc_foreign FOREIGN KEY (ref_funcionario_exc) REFERENCES portal.funcionario(ref_cod_pessoa_fj) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: agenda_compromisso portal_agenda_compromisso_ref_cod_agenda_foreign; Type: FK CONSTRAINT; Schema: portal; Owner: -
--

ALTER TABLE ONLY portal.agenda_compromisso
    ADD CONSTRAINT portal_agenda_compromisso_ref_cod_agenda_foreign FOREIGN KEY (ref_cod_agenda) REFERENCES portal.agenda(cod_agenda) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: agenda_compromisso portal_agenda_compromisso_ref_ref_cod_pessoa_cad_foreign; Type: FK CONSTRAINT; Schema: portal; Owner: -
--

ALTER TABLE ONLY portal.agenda_compromisso
    ADD CONSTRAINT portal_agenda_compromisso_ref_ref_cod_pessoa_cad_foreign FOREIGN KEY (ref_ref_cod_pessoa_cad) REFERENCES portal.funcionario(ref_cod_pessoa_fj) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: agenda portal_agenda_ref_ref_cod_pessoa_cad_foreign; Type: FK CONSTRAINT; Schema: portal; Owner: -
--

ALTER TABLE ONLY portal.agenda
    ADD CONSTRAINT portal_agenda_ref_ref_cod_pessoa_cad_foreign FOREIGN KEY (ref_ref_cod_pessoa_cad) REFERENCES portal.funcionario(ref_cod_pessoa_fj) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: agenda portal_agenda_ref_ref_cod_pessoa_exc_foreign; Type: FK CONSTRAINT; Schema: portal; Owner: -
--

ALTER TABLE ONLY portal.agenda
    ADD CONSTRAINT portal_agenda_ref_ref_cod_pessoa_exc_foreign FOREIGN KEY (ref_ref_cod_pessoa_exc) REFERENCES portal.funcionario(ref_cod_pessoa_fj) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: agenda portal_agenda_ref_ref_cod_pessoa_own_foreign; Type: FK CONSTRAINT; Schema: portal; Owner: -
--

ALTER TABLE ONLY portal.agenda
    ADD CONSTRAINT portal_agenda_ref_ref_cod_pessoa_own_foreign FOREIGN KEY (ref_ref_cod_pessoa_own) REFERENCES portal.funcionario(ref_cod_pessoa_fj) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: agenda_responsavel portal_agenda_responsavel_ref_cod_agenda_foreign; Type: FK CONSTRAINT; Schema: portal; Owner: -
--

ALTER TABLE ONLY portal.agenda_responsavel
    ADD CONSTRAINT portal_agenda_responsavel_ref_cod_agenda_foreign FOREIGN KEY (ref_cod_agenda) REFERENCES portal.agenda(cod_agenda) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: agenda_responsavel portal_agenda_responsavel_ref_ref_cod_pessoa_fj_foreign; Type: FK CONSTRAINT; Schema: portal; Owner: -
--

ALTER TABLE ONLY portal.agenda_responsavel
    ADD CONSTRAINT portal_agenda_responsavel_ref_ref_cod_pessoa_fj_foreign FOREIGN KEY (ref_ref_cod_pessoa_fj) REFERENCES portal.funcionario(ref_cod_pessoa_fj) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: funcionario portal_funcionario_ref_ref_cod_pessoa_fj_foreign; Type: FK CONSTRAINT; Schema: portal; Owner: -
--

ALTER TABLE ONLY portal.funcionario
    ADD CONSTRAINT portal_funcionario_ref_ref_cod_pessoa_fj_foreign FOREIGN KEY (ref_ref_cod_pessoa_fj) REFERENCES portal.funcionario(ref_cod_pessoa_fj) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

\unrestrict mzdzcgw27YG4b4RVMLM5H0PIzma5XE5EXtu1cQGzuMZQZLI8BdKKZi8b08L7xnC

--
-- PostgreSQL database dump
--

\restrict oNN2crCwfJVP0yAR8lyLnG2bS8JExy8GvqY2ZPZtaxRcMpy8Y30Sml1jy2EROVQ

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: migrations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.migrations (id, migration, batch) FROM stdin;
1	2014_10_12_000000_create_users_table	1
2	2014_10_12_100000_create_password_resets_table	1
3	2019_12_01_100000_create_audit_table	1
4	2019_12_14_000001_create_personal_access_tokens_table	1
5	2020_01_01_000000_create_schemas	1
6	2020_01_01_000001_create_extensions	1
7	2020_01_01_000002_create_types	1
8	2020_01_01_000003_add_function_public_commacat_ignore_nulls	1
9	2020_01_01_000003_audit_functions	1
10	2020_01_01_000004_create_aggregates	1
11	2020_01_01_110000_create_cadastro_codigo_cartorio_inep_table	1
12	2020_01_01_110000_create_cadastro_deficiencia_excluidos_table	1
13	2020_01_01_110000_create_cadastro_deficiencia_table	1
14	2020_01_01_110000_create_cadastro_documento_table	1
15	2020_01_01_110000_create_cadastro_escolaridade_table	1
16	2020_01_01_110000_create_cadastro_estado_civil_table	1
17	2020_01_01_110000_create_cadastro_fisica_deficiencia_table	1
18	2020_01_01_110000_create_cadastro_fisica_foto_table	1
19	2020_01_01_110000_create_cadastro_fisica_raca_table	1
20	2020_01_01_110000_create_cadastro_fisica_table	1
21	2020_01_01_110000_create_cadastro_fone_pessoa_table	1
22	2020_01_01_110000_create_cadastro_juridica_table	1
23	2020_01_01_110000_create_cadastro_orgao_emissor_rg_table	1
24	2020_01_01_110000_create_cadastro_pessoa_table	1
25	2020_01_01_110000_create_cadastro_raca_table	1
26	2020_01_01_110000_create_cities_table	1
27	2020_01_01_110000_create_countries_table	1
28	2020_01_01_110000_create_districts_table	1
29	2020_01_01_110000_create_educacenso_imports_table	1
30	2020_01_01_110000_create_employee_graduation_disciplines_table	1
31	2020_01_01_110000_create_employee_graduations_table	1
32	2020_01_01_110000_create_log_unification_old_data_table	1
33	2020_01_01_110000_create_log_unifications_table	1
34	2020_01_01_110000_create_manager_access_criterias_table	1
35	2020_01_01_110000_create_manager_link_types_table	1
36	2020_01_01_110000_create_manager_roles_table	1
37	2020_01_01_110000_create_menus_table	1
38	2020_01_01_110000_create_modules_area_conhecimento_excluidos_table	1
39	2020_01_01_110000_create_modules_area_conhecimento_table	1
40	2020_01_01_110000_create_modules_auditoria_table	1
41	2020_01_01_110000_create_modules_calendario_turma_table	1
42	2020_01_01_110000_create_modules_componente_curricular_ano_escolar_excluidos_table	1
43	2020_01_01_110000_create_modules_componente_curricular_ano_escolar_table	1
\.


--
-- Name: migrations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.migrations_id_seq', 43, true);


--
-- PostgreSQL database dump complete
--

\unrestrict oNN2crCwfJVP0yAR8lyLnG2bS8JExy8GvqY2ZPZtaxRcMpy8Y30Sml1jy2EROVQ
