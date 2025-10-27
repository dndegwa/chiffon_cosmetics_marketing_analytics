--
-- PostgreSQL database dump
--

\restrict FQbQivLGQ7YwkXyPQGW42519gYFkjQYUBC7rzWQRLeRHTph9B17m4cs3WrKX6t0

-- Dumped from database version 18.0
-- Dumped by pg_dump version 18.0

-- Started on 2025-10-27 22:54:01

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
-- TOC entry 5 (class 2615 OID 16806)
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO postgres;

--
-- TOC entry 4995 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS '';


--
-- TOC entry 237 (class 1255 OID 20046)
-- Name: etl_load_dim_campaign(); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.etl_load_dim_campaign()
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO dim_campaign (campaign_name, campaign_code)
    SELECT DISTINCT 
        "Campaign name",
        CASE 
            WHEN "Campaign name" = 'Chiffon Brand Awareness' THEN 'CHIFFON_BRAND_2025'
            WHEN "Campaign name" = 'Valentine Push' THEN 'VALPUSH_2025'
            WHEN "Campaign name" = 'New Store Launch' THEN 'NEW_STORE_2025'
            WHEN "Campaign name" = 'Holiday Promo Q4' THEN 'HOLIDAY_Q4_2025'
            WHEN "Campaign name" = 'Referral Boost' THEN 'REFERRAL_2025'
            ELSE "Campaign name"
        END
    FROM stg_google_ads
    ON CONFLICT (campaign_name) DO NOTHING;
END;
$$;


ALTER PROCEDURE public.etl_load_dim_campaign() OWNER TO postgres;

--
-- TOC entry 238 (class 1255 OID 20047)
-- Name: etl_load_dim_customer(); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.etl_load_dim_customer()
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO dim_customer (company_name, country)
    SELECT DISTINCT "Company name", "Country"
    FROM stg_hubspot_contacts
    WHERE "Company name" IS NOT NULL
    ON CONFLICT (company_name) DO NOTHING;
END;
$$;


ALTER PROCEDURE public.etl_load_dim_customer() OWNER TO postgres;

--
-- TOC entry 236 (class 1255 OID 20045)
-- Name: etl_load_dim_date(); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.etl_load_dim_date()
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO dim_date (date, year, quarter, month, day, month_name, is_weekday)
    SELECT DISTINCT
        date,
        EXTRACT(YEAR FROM date),
        EXTRACT(QUARTER FROM date),
        EXTRACT(MONTH FROM date),
        EXTRACT(DAY FROM date),
        TO_CHAR(date, 'Month'),
        CASE WHEN EXTRACT(ISODOW FROM date) IN (6,7) THEN false ELSE true END
    FROM (
        SELECT "Date"::DATE as date FROM stg_google_ads
        UNION SELECT "Create date"::DATE as date FROM stg_hubspot_contacts
        UNION SELECT "Posting Date"::DATE as date FROM stg_sap_financials
    ) all_dates
    ON CONFLICT (date) DO NOTHING;
END;
$$;


ALTER PROCEDURE public.etl_load_dim_date() OWNER TO postgres;

--
-- TOC entry 239 (class 1255 OID 20048)
-- Name: etl_load_fact_ad_performance(); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.etl_load_fact_ad_performance()
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO fact_ad_performance (date_id, campaign_id, impressions, clicks, cost)
    SELECT 
        d.date_id,
        c.campaign_id,
        ga."Impressions",
        ga."Clicks",
        ga."Cost"
    FROM stg_google_ads ga
    JOIN dim_date d ON ga."Date"::DATE = d.date
    JOIN dim_campaign c ON ga."Campaign name" = c.campaign_name;
END;
$$;


ALTER PROCEDURE public.etl_load_fact_ad_performance() OWNER TO postgres;

--
-- TOC entry 240 (class 1255 OID 20049)
-- Name: etl_load_fact_finance(); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.etl_load_fact_finance()
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO fact_finance (date_id, internal_order, company_code, cost_center, amount, budget, variance, source_system)
    SELECT 
        d.date_id,
        s."Internal Order",
        s."Company Code",
        s."Cost Center",
        s."Amount in local currency",
        s."Budget",
        s."Variance",
        'SAP'
    FROM stg_sap_financials s
    JOIN dim_date d ON s."Posting Date"::DATE = d.date;
END;
$$;


ALTER PROCEDURE public.etl_load_fact_finance() OWNER TO postgres;

--
-- TOC entry 241 (class 1255 OID 20050)
-- Name: etl_load_fact_leads(); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.etl_load_fact_leads()
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO fact_leads (date_id, campaign_id, customer_id, lifecycle_stage, source_system)
    SELECT 
        d.date_id,
        c.campaign_id,
        cust.customer_id,
        h."Lifecycle stage",
        'HubSpot'
    FROM stg_hubspot_contacts h
    JOIN dim_date d ON h."Create date"::DATE = d.date
    JOIN dim_campaign c ON h."Campaign" = c.campaign_name
    JOIN dim_customer cust ON h."Company name" = cust.company_name;
END;
$$;


ALTER PROCEDURE public.etl_load_fact_leads() OWNER TO postgres;

--
-- TOC entry 246 (class 1255 OID 20051)
-- Name: etl_load_fact_revenue(); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.etl_load_fact_revenue()
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO fact_revenue (date_id, campaign_id, customer_id, deal_amount, source_system)
    SELECT 
        d.date_id,
        c.campaign_id,
        cust.customer_id,
        h."Recent deal amount",
        'HubSpot'
    FROM stg_hubspot_contacts h
    JOIN dim_date d ON h."Recent deal close date"::DATE = d.date
    JOIN dim_campaign c ON h."Campaign" = c.campaign_name
    JOIN dim_customer cust ON h."Company name" = cust.company_name
    WHERE h."Recent deal amount" IS NOT NULL;
END;
$$;


ALTER PROCEDURE public.etl_load_fact_revenue() OWNER TO postgres;

--
-- TOC entry 247 (class 1255 OID 20052)
-- Name: run_full_etl(); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.run_full_etl()
    LANGUAGE plpgsql
    AS $$
BEGIN
    CALL etl_load_dim_date();
    CALL etl_load_dim_campaign();
    CALL etl_load_dim_customer();
    CALL etl_load_fact_ad_performance();
    CALL etl_load_fact_leads();
    CALL etl_load_fact_revenue();
    CALL etl_load_fact_finance();
END;
$$;


ALTER PROCEDURE public.run_full_etl() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 222 (class 1259 OID 19922)
-- Name: dim_campaign; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dim_campaign (
    campaign_id integer NOT NULL,
    campaign_name text NOT NULL,
    campaign_code text NOT NULL
);


ALTER TABLE public.dim_campaign OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 19921)
-- Name: dim_campaign_campaign_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dim_campaign_campaign_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.dim_campaign_campaign_id_seq OWNER TO postgres;

--
-- TOC entry 4997 (class 0 OID 0)
-- Dependencies: 221
-- Name: dim_campaign_campaign_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.dim_campaign_campaign_id_seq OWNED BY public.dim_campaign.campaign_id;


--
-- TOC entry 224 (class 1259 OID 19938)
-- Name: dim_customer; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dim_customer (
    customer_id integer NOT NULL,
    company_name text NOT NULL,
    country text
);


ALTER TABLE public.dim_customer OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 19937)
-- Name: dim_customer_customer_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dim_customer_customer_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.dim_customer_customer_id_seq OWNER TO postgres;

--
-- TOC entry 4998 (class 0 OID 0)
-- Dependencies: 223
-- Name: dim_customer_customer_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.dim_customer_customer_id_seq OWNED BY public.dim_customer.customer_id;


--
-- TOC entry 220 (class 1259 OID 19903)
-- Name: dim_date; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dim_date (
    date_id integer NOT NULL,
    date date NOT NULL,
    year integer NOT NULL,
    quarter integer NOT NULL,
    month integer NOT NULL,
    day integer NOT NULL,
    month_name text NOT NULL,
    is_weekday boolean NOT NULL
);


ALTER TABLE public.dim_date OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 19902)
-- Name: dim_date_date_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dim_date_date_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.dim_date_date_id_seq OWNER TO postgres;

--
-- TOC entry 4999 (class 0 OID 0)
-- Dependencies: 219
-- Name: dim_date_date_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.dim_date_date_id_seq OWNED BY public.dim_date.date_id;


--
-- TOC entry 226 (class 1259 OID 19951)
-- Name: fact_ad_performance; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fact_ad_performance (
    fact_id integer NOT NULL,
    date_id integer NOT NULL,
    campaign_id integer NOT NULL,
    impressions integer,
    clicks integer,
    cost numeric
);


ALTER TABLE public.fact_ad_performance OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 19950)
-- Name: fact_ad_performance_fact_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.fact_ad_performance_fact_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.fact_ad_performance_fact_id_seq OWNER TO postgres;

--
-- TOC entry 5000 (class 0 OID 0)
-- Dependencies: 225
-- Name: fact_ad_performance_fact_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.fact_ad_performance_fact_id_seq OWNED BY public.fact_ad_performance.fact_id;


--
-- TOC entry 228 (class 1259 OID 19973)
-- Name: fact_finance; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fact_finance (
    finance_id integer NOT NULL,
    date_id integer NOT NULL,
    internal_order text NOT NULL,
    company_code text,
    cost_center text,
    amount numeric,
    budget numeric,
    variance numeric,
    source_system text
);


ALTER TABLE public.fact_finance OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 19972)
-- Name: fact_finance_finance_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.fact_finance_finance_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.fact_finance_finance_id_seq OWNER TO postgres;

--
-- TOC entry 5001 (class 0 OID 0)
-- Dependencies: 227
-- Name: fact_finance_finance_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.fact_finance_finance_id_seq OWNED BY public.fact_finance.finance_id;


--
-- TOC entry 230 (class 1259 OID 19990)
-- Name: fact_leads; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fact_leads (
    lead_id integer NOT NULL,
    date_id integer NOT NULL,
    campaign_id integer NOT NULL,
    customer_id integer NOT NULL,
    lifecycle_stage text,
    source_system text
);


ALTER TABLE public.fact_leads OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 19989)
-- Name: fact_leads_lead_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.fact_leads_lead_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.fact_leads_lead_id_seq OWNER TO postgres;

--
-- TOC entry 5002 (class 0 OID 0)
-- Dependencies: 229
-- Name: fact_leads_lead_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.fact_leads_lead_id_seq OWNED BY public.fact_leads.lead_id;


--
-- TOC entry 232 (class 1259 OID 20018)
-- Name: fact_revenue; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fact_revenue (
    revenue_id integer NOT NULL,
    date_id integer NOT NULL,
    campaign_id integer NOT NULL,
    customer_id integer NOT NULL,
    deal_amount numeric,
    source_system text
);


ALTER TABLE public.fact_revenue OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 20017)
-- Name: fact_revenue_revenue_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.fact_revenue_revenue_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.fact_revenue_revenue_id_seq OWNER TO postgres;

--
-- TOC entry 5003 (class 0 OID 0)
-- Dependencies: 231
-- Name: fact_revenue_revenue_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.fact_revenue_revenue_id_seq OWNED BY public.fact_revenue.revenue_id;


--
-- TOC entry 233 (class 1259 OID 20053)
-- Name: stg_google_ads; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stg_google_ads (
    "Campaign name" text,
    "Ad group" text,
    "Date" text,
    "Impressions" bigint,
    "Clicks" bigint,
    "Average CPC" double precision,
    "Cost" double precision,
    "Conversions" bigint,
    "Conversion value" bigint,
    "CTR" double precision,
    "Device" text,
    "Network" text
);


ALTER TABLE public.stg_google_ads OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 20058)
-- Name: stg_hubspot_contacts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stg_hubspot_contacts (
    "Record ID" bigint,
    "Email" text,
    "First name" text,
    "Last name" text,
    "Lifecycle stage" text,
    "Original source" text,
    "Original source drill-down 1" text,
    "Create date" text,
    "Recent deal close date" text,
    "Recent deal amount" double precision,
    "Campaign" text,
    "Owner" text,
    "Company name" text,
    "Country" text
);


ALTER TABLE public.stg_hubspot_contacts OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 20063)
-- Name: stg_sap_financials; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stg_sap_financials (
    "Company Code" bigint,
    "Cost Center" text,
    "Cost Element" bigint,
    "GL Account Name" text,
    "Fiscal Year/Period" text,
    "Currency" text,
    "Amount in local currency" double precision,
    "Budget" double precision,
    "Variance" double precision,
    "Internal Order" text,
    "Posting Date" text
);


ALTER TABLE public.stg_sap_financials OWNER TO postgres;

--
-- TOC entry 4806 (class 2604 OID 19925)
-- Name: dim_campaign campaign_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dim_campaign ALTER COLUMN campaign_id SET DEFAULT nextval('public.dim_campaign_campaign_id_seq'::regclass);


--
-- TOC entry 4807 (class 2604 OID 19941)
-- Name: dim_customer customer_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dim_customer ALTER COLUMN customer_id SET DEFAULT nextval('public.dim_customer_customer_id_seq'::regclass);


--
-- TOC entry 4805 (class 2604 OID 19906)
-- Name: dim_date date_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dim_date ALTER COLUMN date_id SET DEFAULT nextval('public.dim_date_date_id_seq'::regclass);


--
-- TOC entry 4808 (class 2604 OID 19954)
-- Name: fact_ad_performance fact_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fact_ad_performance ALTER COLUMN fact_id SET DEFAULT nextval('public.fact_ad_performance_fact_id_seq'::regclass);


--
-- TOC entry 4809 (class 2604 OID 19976)
-- Name: fact_finance finance_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fact_finance ALTER COLUMN finance_id SET DEFAULT nextval('public.fact_finance_finance_id_seq'::regclass);


--
-- TOC entry 4810 (class 2604 OID 19993)
-- Name: fact_leads lead_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fact_leads ALTER COLUMN lead_id SET DEFAULT nextval('public.fact_leads_lead_id_seq'::regclass);


--
-- TOC entry 4811 (class 2604 OID 20021)
-- Name: fact_revenue revenue_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fact_revenue ALTER COLUMN revenue_id SET DEFAULT nextval('public.fact_revenue_revenue_id_seq'::regclass);


--
-- TOC entry 4817 (class 2606 OID 19936)
-- Name: dim_campaign dim_campaign_campaign_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dim_campaign
    ADD CONSTRAINT dim_campaign_campaign_code_key UNIQUE (campaign_code);


--
-- TOC entry 4819 (class 2606 OID 19934)
-- Name: dim_campaign dim_campaign_campaign_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dim_campaign
    ADD CONSTRAINT dim_campaign_campaign_name_key UNIQUE (campaign_name);


--
-- TOC entry 4821 (class 2606 OID 19932)
-- Name: dim_campaign dim_campaign_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dim_campaign
    ADD CONSTRAINT dim_campaign_pkey PRIMARY KEY (campaign_id);


--
-- TOC entry 4823 (class 2606 OID 19949)
-- Name: dim_customer dim_customer_company_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dim_customer
    ADD CONSTRAINT dim_customer_company_name_key UNIQUE (company_name);


--
-- TOC entry 4825 (class 2606 OID 19947)
-- Name: dim_customer dim_customer_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dim_customer
    ADD CONSTRAINT dim_customer_pkey PRIMARY KEY (customer_id);


--
-- TOC entry 4813 (class 2606 OID 19920)
-- Name: dim_date dim_date_date_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dim_date
    ADD CONSTRAINT dim_date_date_key UNIQUE (date);


--
-- TOC entry 4815 (class 2606 OID 19918)
-- Name: dim_date dim_date_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dim_date
    ADD CONSTRAINT dim_date_pkey PRIMARY KEY (date_id);


--
-- TOC entry 4827 (class 2606 OID 19961)
-- Name: fact_ad_performance fact_ad_performance_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fact_ad_performance
    ADD CONSTRAINT fact_ad_performance_pkey PRIMARY KEY (fact_id);


--
-- TOC entry 4829 (class 2606 OID 19983)
-- Name: fact_finance fact_finance_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fact_finance
    ADD CONSTRAINT fact_finance_pkey PRIMARY KEY (finance_id);


--
-- TOC entry 4831 (class 2606 OID 20001)
-- Name: fact_leads fact_leads_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fact_leads
    ADD CONSTRAINT fact_leads_pkey PRIMARY KEY (lead_id);


--
-- TOC entry 4833 (class 2606 OID 20029)
-- Name: fact_revenue fact_revenue_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fact_revenue
    ADD CONSTRAINT fact_revenue_pkey PRIMARY KEY (revenue_id);


--
-- TOC entry 4834 (class 2606 OID 19967)
-- Name: fact_ad_performance fact_ad_performance_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fact_ad_performance
    ADD CONSTRAINT fact_ad_performance_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.dim_campaign(campaign_id);


--
-- TOC entry 4835 (class 2606 OID 19962)
-- Name: fact_ad_performance fact_ad_performance_date_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fact_ad_performance
    ADD CONSTRAINT fact_ad_performance_date_id_fkey FOREIGN KEY (date_id) REFERENCES public.dim_date(date_id);


--
-- TOC entry 4836 (class 2606 OID 19984)
-- Name: fact_finance fact_finance_date_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fact_finance
    ADD CONSTRAINT fact_finance_date_id_fkey FOREIGN KEY (date_id) REFERENCES public.dim_date(date_id);


--
-- TOC entry 4837 (class 2606 OID 20007)
-- Name: fact_leads fact_leads_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fact_leads
    ADD CONSTRAINT fact_leads_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.dim_campaign(campaign_id);


--
-- TOC entry 4838 (class 2606 OID 20012)
-- Name: fact_leads fact_leads_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fact_leads
    ADD CONSTRAINT fact_leads_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.dim_customer(customer_id);


--
-- TOC entry 4839 (class 2606 OID 20002)
-- Name: fact_leads fact_leads_date_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fact_leads
    ADD CONSTRAINT fact_leads_date_id_fkey FOREIGN KEY (date_id) REFERENCES public.dim_date(date_id);


--
-- TOC entry 4840 (class 2606 OID 20035)
-- Name: fact_revenue fact_revenue_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fact_revenue
    ADD CONSTRAINT fact_revenue_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.dim_campaign(campaign_id);


--
-- TOC entry 4841 (class 2606 OID 20040)
-- Name: fact_revenue fact_revenue_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fact_revenue
    ADD CONSTRAINT fact_revenue_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.dim_customer(customer_id);


--
-- TOC entry 4842 (class 2606 OID 20030)
-- Name: fact_revenue fact_revenue_date_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fact_revenue
    ADD CONSTRAINT fact_revenue_date_id_fkey FOREIGN KEY (date_id) REFERENCES public.dim_date(date_id);


--
-- TOC entry 4996 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;


-- Completed on 2025-10-27 22:54:02

--
-- PostgreSQL database dump complete
--

\unrestrict FQbQivLGQ7YwkXyPQGW42519gYFkjQYUBC7rzWQRLeRHTph9B17m4cs3WrKX6t0

