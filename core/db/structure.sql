--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: currency; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN currency AS character(3) NOT NULL DEFAULT 'USD'::bpchar;


--
-- Name: identifier; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN identifier AS integer
  CONSTRAINT check_identifier CHECK ((VALUE > 0));


--
-- Name: numeric_money; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN numeric_money AS numeric(10,2);


--
-- Name: check_product_page_text_field_present(character varying, identifier, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION check_product_page_text_field_present(path character varying, page_id identifier, value character varying) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $_$
      SELECT
        CASE WHEN $1 = 'index' AND $2 IS NOT NULL
        THEN $3 IS NULL
        ELSE LENGTH($3) >= 1
        END;
    $_$;


--
-- Name: friendly_id_slugs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE friendly_id_slugs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: friendly_id_slugs; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE friendly_id_slugs (
    id identifier DEFAULT nextval('friendly_id_slugs_id_seq'::regclass) NOT NULL,
    slug character varying(255) NOT NULL,
    sluggable_id identifier NOT NULL,
    sluggable_type character varying(255) NOT NULL,
    scope character varying(255),
    deleted_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    CONSTRAINT check_friendly_id_slugs_deleted_at CHECK ((deleted_at >= created_at)),
    CONSTRAINT check_friendly_id_slugs_scope CHECK ((scope IS NULL)),
    CONSTRAINT check_friendly_id_slugs_slug CHECK ((char_length((slug)::text) >= 1)),
    CONSTRAINT check_friendly_id_slugs_sluggable_type CHECK (((sluggable_type)::text = 'Spree::Product'::text)),
    CONSTRAINT check_friendly_id_slugs_updated_at CHECK ((updated_at >= created_at))
);


--
-- Name: spree_option_types; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_option_types (
    id identifier NOT NULL,
    name character varying(13) NOT NULL,
    presentation character varying(13) NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    CONSTRAINT check_spree_option_types_position CHECK (("position" >= 0)),
    CONSTRAINT check_spree_option_types_updated_at CHECK ((updated_at >= created_at))
);


--
-- Name: spree_option_values; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_option_values (
    id identifier NOT NULL,
    "position" integer,
    name character varying(255),
    presentation character varying(255),
    option_type_id identifier,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: spree_option_values_variants; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_option_values_variants (
    variant_id identifier,
    option_value_id identifier
);


--
-- Name: spree_products; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_products (
    id identifier NOT NULL,
    name character varying(255) DEFAULT ''::character varying NOT NULL,
    description text,
    available_on timestamp without time zone,
    deleted_at timestamp without time zone,
    slug character varying(255),
    meta_description text,
    meta_keywords character varying(255),
    tax_category_id identifier,
    shipping_category_id identifier NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    promotionable boolean DEFAULT true NOT NULL,
    meta_title character varying(255) DEFAULT ''::character varying NOT NULL,
    CONSTRAINT check_spree_products_deleted_at CHECK (((deleted_at IS NULL) OR (deleted_at >= created_at))),
    CONSTRAINT check_spree_products_name CHECK ((char_length((name)::text) >= 1)),
    CONSTRAINT check_spree_products_slug CHECK ((char_length((slug)::text) >= 3)),
    CONSTRAINT check_spree_products_updated_at CHECK ((updated_at >= created_at))
);


--
-- Name: spree_variants; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_variants (
    id identifier NOT NULL,
    sku character varying(16) DEFAULT ''::character varying NOT NULL,
    weight numeric(8,2) DEFAULT 0.0 NOT NULL,
    height numeric(8,2),
    width numeric(8,2),
    depth numeric(8,2),
    deleted_at timestamp without time zone,
    is_master boolean DEFAULT false NOT NULL,
    product_id identifier NOT NULL,
    cost_price numeric_money,
    "position" smallint DEFAULT 0,
    cost_currency currency NOT NULL,
    track_inventory boolean DEFAULT true NOT NULL,
    updated_at timestamp without time zone,
    tax_category_id identifier,
    stock_items_count integer DEFAULT 0 NOT NULL,
    CONSTRAINT check_spree_variants_cost_price CHECK (((cost_price IS NULL) OR ((cost_price)::numeric >= (0)::numeric))),
    CONSTRAINT check_spree_variants_depth CHECK (((depth IS NULL) OR (depth >= (0)::numeric))),
    CONSTRAINT check_spree_variants_height CHECK (((height IS NULL) OR (height >= (0)::numeric))),
    CONSTRAINT check_spree_variants_position CHECK (("position" >= 0)),
    CONSTRAINT check_spree_variants_sku CHECK (((length((sku)::text) = 0) OR (length((sku)::text) >= 2))),
    CONSTRAINT check_spree_variants_stock_items_count CHECK ((stock_items_count >= 0)),
    CONSTRAINT check_spree_variants_tax_category_id CHECK ((tax_category_id IS NULL)),
    CONSTRAINT check_spree_variants_weight CHECK ((weight >= (0)::numeric)),
    CONSTRAINT check_spree_variants_width CHECK (((width IS NULL) OR (width >= (0)::numeric)))
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE schema_migrations (
    version character varying(255) NOT NULL
);


--
-- Name: spree_addresses; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_addresses (
    id identifier NOT NULL,
    firstname character varying(255) NOT NULL,
    lastname character varying(255) NOT NULL,
    address1 character varying(255) NOT NULL,
    address2 character varying(255),
    city character varying(255) NOT NULL,
    zipcode character varying(255) NOT NULL,
    phone character varying(255) NOT NULL,
    state_name character varying(255),
    alternative_phone character varying(255),
    company character varying(255),
    state_id identifier NOT NULL,
    country_id identifier NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    CONSTRAINT check_spree_addresses_address1 CHECK ((char_length((address1)::text) >= 1)),
    CONSTRAINT check_spree_addresses_city CHECK ((char_length((city)::text) >= 1)),
    CONSTRAINT check_spree_addresses_firstname CHECK ((char_length((firstname)::text) >= 1)),
    CONSTRAINT check_spree_addresses_lastname CHECK ((char_length((lastname)::text) >= 1)),
    CONSTRAINT check_spree_addresses_phone CHECK ((char_length((phone)::text) >= 1)),
    CONSTRAINT check_spree_addresses_state_name CHECK ((state_name IS NULL)),
    CONSTRAINT check_spree_addresses_updated_at CHECK ((updated_at >= created_at)),
    CONSTRAINT check_spree_addresses_zipcode CHECK ((char_length((zipcode)::text) >= 1))
);


--
-- Name: spree_addresses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_addresses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_addresses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_addresses_id_seq OWNED BY spree_addresses.id;


--
-- Name: spree_adjustments; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_adjustments (
    id identifier NOT NULL,
    source_id identifier,
    source_type character varying(255),
    adjustable_id identifier NOT NULL,
    adjustable_type character varying(255) NOT NULL,
    amount numeric_money NOT NULL,
    label character varying(255),
    mandatory boolean,
    eligible boolean DEFAULT true NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    state character varying(255) NOT NULL,
    order_id identifier NOT NULL,
    included boolean DEFAULT false NOT NULL,
    CONSTRAINT check_spree_adjustments_adjustable CHECK ((((adjustable_type)::text <> 'Spree::Order'::text) OR ((order_id)::integer = (adjustable_id)::integer)))
);


--
-- Name: spree_adjustments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_adjustments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_adjustments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_adjustments_id_seq OWNED BY spree_adjustments.id;


--
-- Name: spree_assets; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_assets (
    id identifier NOT NULL,
    viewable_id identifier,
    viewable_type character varying(255),
    attachment_width integer,
    attachment_height integer,
    attachment_file_size integer,
    "position" integer,
    attachment_content_type character varying(255),
    attachment_file_name character varying(255),
    type character varying(75),
    attachment_updated_at timestamp without time zone,
    alt text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: spree_assets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_assets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_assets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_assets_id_seq OWNED BY spree_assets.id;


--
-- Name: spree_calculators; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_calculators (
    id identifier NOT NULL,
    type character varying(255),
    calculable_id identifier,
    calculable_type character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    preferences text
);


--
-- Name: spree_calculators_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_calculators_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_calculators_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_calculators_id_seq OWNED BY spree_calculators.id;


--
-- Name: spree_configurations; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_configurations (
    id identifier NOT NULL,
    name character varying(255),
    type character varying(50),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: spree_configurations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_configurations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_configurations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_configurations_id_seq OWNED BY spree_configurations.id;


--
-- Name: spree_countries; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_countries (
    id identifier NOT NULL,
    iso_name character varying(15) NOT NULL,
    iso character(2) NOT NULL,
    iso3 character(3) NOT NULL,
    name character varying(30) NOT NULL,
    numcode smallint NOT NULL,
    states_required boolean DEFAULT true NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    CONSTRAINT check_spree_countries_iso CHECK ((char_length(iso) = 2)),
    CONSTRAINT check_spree_countries_iso3 CHECK ((char_length(iso3) = 3)),
    CONSTRAINT check_spree_countries_iso_name CHECK ((char_length((iso_name)::text) > 0)),
    CONSTRAINT check_spree_countries_name CHECK ((char_length((name)::text) > 0)),
    CONSTRAINT check_spree_countries_numcode CHECK (((numcode >= 1) AND (numcode <= 999)))
);


--
-- Name: spree_countries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_countries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_countries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_countries_id_seq OWNED BY spree_countries.id;


--
-- Name: spree_credit_cards; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_credit_cards (
    id identifier NOT NULL,
    month character varying(255),
    year character varying(255),
    cc_type character varying(255),
    last_digits character varying(255),
    address_id identifier,
    gateway_customer_profile_id character varying(255),
    gateway_payment_profile_id character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    name character varying(255),
    user_id identifier,
    payment_method_id identifier,
    "default" boolean DEFAULT false NOT NULL
);


--
-- Name: spree_credit_cards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_credit_cards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_credit_cards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_credit_cards_id_seq OWNED BY spree_credit_cards.id;


--
-- Name: spree_customer_returns_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_customer_returns_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_customer_returns; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_customer_returns (
    id identifier DEFAULT nextval('spree_customer_returns_id_seq'::regclass) NOT NULL,
    number character varying(11) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    stock_location_id identifier NOT NULL,
    CONSTRAINT check_spree_customer_returns_number CHECK ((char_length((number)::text) = 11)),
    CONSTRAINT check_spree_customer_returns_updated_at CHECK ((updated_at >= created_at))
);


--
-- Name: spree_gateways; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_gateways (
    id identifier NOT NULL,
    type character varying(255),
    name character varying(255),
    description text,
    active boolean DEFAULT true,
    environment character varying(255) DEFAULT 'development'::character varying,
    server character varying(255) DEFAULT 'test'::character varying,
    test_mode boolean DEFAULT true,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    preferences text
);


--
-- Name: spree_gateways_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_gateways_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_gateways_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_gateways_id_seq OWNED BY spree_gateways.id;


--
-- Name: spree_inventory_units; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_inventory_units (
    id identifier NOT NULL,
    state character varying(11) NOT NULL,
    variant_id identifier NOT NULL,
    order_id identifier NOT NULL,
    shipment_id identifier NOT NULL,
    return_authorization_id identifier,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    pending boolean DEFAULT true NOT NULL,
    line_item_id identifier NOT NULL,
    CONSTRAINT check_spree_inventory_units_state CHECK (((state)::text = ANY (ARRAY[('on_hand'::character varying)::text, ('shipped'::character varying)::text, ('backordered'::character varying)::text, ('returned'::character varying)::text])))
);


--
-- Name: spree_inventory_units_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_inventory_units_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_inventory_units_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_inventory_units_id_seq OWNED BY spree_inventory_units.id;


--
-- Name: spree_line_items; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_line_items (
    id identifier NOT NULL,
    variant_id identifier,
    order_id identifier,
    quantity integer NOT NULL,
    price numeric_money NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    currency currency NOT NULL,
    cost_price numeric_money,
    tax_category_id identifier,
    adjustment_total numeric_money DEFAULT 0 NOT NULL,
    additional_tax_total numeric_money DEFAULT 0 NOT NULL,
    promo_total numeric_money DEFAULT 0 NOT NULL,
    included_tax_total numeric_money DEFAULT 0 NOT NULL,
    pre_tax_amount numeric_money DEFAULT 0 NOT NULL,
    CONSTRAINT check_spree_line_items_cost_price CHECK (((cost_price IS NULL) OR ((cost_price)::numeric >= (0)::numeric))),
    CONSTRAINT check_spree_line_items_price CHECK (((price)::numeric >= (0)::numeric)),
    CONSTRAINT check_spree_line_items_promo_total CHECK (((promo_total)::numeric <= (0)::numeric))
);


--
-- Name: spree_line_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_line_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_line_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_line_items_id_seq OWNED BY spree_line_items.id;


--
-- Name: spree_log_entries; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_log_entries (
    id identifier NOT NULL,
    source_id identifier,
    source_type character varying(255),
    details text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: spree_log_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_log_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_log_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_log_entries_id_seq OWNED BY spree_log_entries.id;


--
-- Name: spree_new_adjustments; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_new_adjustments (
    id identifier NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: spree_new_adjustments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_new_adjustments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_new_adjustments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_new_adjustments_id_seq OWNED BY spree_new_adjustments.id;


--
-- Name: spree_option_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_option_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_option_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_option_types_id_seq OWNED BY spree_option_types.id;


--
-- Name: spree_option_types_prototypes; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_option_types_prototypes (
    prototype_id identifier,
    option_type_id identifier
);


--
-- Name: spree_option_values_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_option_values_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_option_values_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_option_values_id_seq OWNED BY spree_option_values.id;


--
-- Name: spree_orders; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_orders (
    id identifier NOT NULL,
    number character varying(15) NOT NULL,
    item_total numeric_money DEFAULT 0.0 NOT NULL,
    total numeric_money DEFAULT 0.0 NOT NULL,
    state character varying(255),
    adjustment_total numeric_money DEFAULT 0.0 NOT NULL,
    user_id identifier,
    completed_at timestamp without time zone,
    bill_address_id identifier,
    ship_address_id identifier,
    payment_total numeric_money DEFAULT 0 NOT NULL,
    shipment_state character varying(255),
    payment_state character varying(255),
    email character varying(255),
    special_instructions text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    currency currency NOT NULL,
    last_ip_address character varying(255),
    created_by_id identifier,
    channel character varying(255) DEFAULT 'spree'::character varying,
    additional_tax_total numeric_money DEFAULT 0 NOT NULL,
    shipment_total numeric_money DEFAULT 0.0 NOT NULL,
    promo_total numeric_money DEFAULT 0 NOT NULL,
    included_tax_total numeric_money DEFAULT 0 NOT NULL,
    item_count integer DEFAULT 0,
    approver_id identifier,
    approved_at timestamp without time zone,
    confirmation_delivered boolean DEFAULT false,
    considered_risky boolean DEFAULT false,
    guest_token character varying(22) NOT NULL,
    state_lock_version integer DEFAULT 0 NOT NULL,
    store_id identifier NOT NULL,
    canceled_at timestamp without time zone,
    canceler_id identifier,
    CONSTRAINT check_spree_orders_canceled_at CHECK ((canceled_at >= created_at)),
    CONSTRAINT check_spree_orders_guest_token CHECK (((length((guest_token)::text) = 22) OR (length((guest_token)::text) = 16))),
    CONSTRAINT check_spree_orders_promo_total CHECK (((promo_total)::numeric <= (0)::numeric))
);


--
-- Name: spree_orders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_orders_id_seq OWNED BY spree_orders.id;


--
-- Name: spree_orders_promotions; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_orders_promotions (
    order_id identifier,
    promotion_id identifier
);


--
-- Name: spree_payment_capture_events; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_payment_capture_events (
    id identifier NOT NULL,
    amount numeric_money DEFAULT 0.0,
    payment_id identifier,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: spree_payment_capture_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_payment_capture_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_payment_capture_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_payment_capture_events_id_seq OWNED BY spree_payment_capture_events.id;


--
-- Name: spree_payment_methods; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_payment_methods (
    id identifier NOT NULL,
    type character varying(255),
    name character varying(255),
    description text,
    active boolean DEFAULT true,
    environment character varying(255) DEFAULT 'development'::character varying,
    deleted_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    display_on character varying(255),
    auto_capture boolean,
    preferences text
);


--
-- Name: spree_payment_methods_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_payment_methods_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_payment_methods_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_payment_methods_id_seq OWNED BY spree_payment_methods.id;


--
-- Name: spree_payments; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_payments (
    id identifier NOT NULL,
    amount numeric_money DEFAULT 0.0 NOT NULL,
    order_id identifier,
    source_id identifier,
    source_type character varying(255),
    payment_method_id identifier,
    state character varying(255),
    response_code character varying(255),
    avs_response character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    identifier character varying(255),
    cvv_response_code character varying(255),
    cvv_response_message character varying(255)
);


--
-- Name: spree_payments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_payments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_payments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_payments_id_seq OWNED BY spree_payments.id;


--
-- Name: spree_preferences; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_preferences (
    id identifier NOT NULL,
    value text,
    key character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: spree_preferences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_preferences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_preferences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_preferences_id_seq OWNED BY spree_preferences.id;


--
-- Name: spree_prices; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_prices (
    id identifier NOT NULL,
    variant_id identifier NOT NULL,
    amount numeric_money,
    currency currency NOT NULL,
    deleted_at timestamp without time zone,
    CONSTRAINT check_spree_prices_amount CHECK (((amount IS NULL) OR ((amount)::numeric >= (0)::numeric)))
);


--
-- Name: spree_prices_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_prices_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_prices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_prices_id_seq OWNED BY spree_prices.id;


--
-- Name: spree_product_option_types; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_product_option_types (
    id identifier NOT NULL,
    "position" integer,
    product_id identifier,
    option_type_id identifier,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: spree_product_option_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_product_option_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_product_option_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_product_option_types_id_seq OWNED BY spree_product_option_types.id;


--
-- Name: spree_product_packages; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_product_packages (
    id identifier NOT NULL,
    product_id identifier NOT NULL,
    length integer DEFAULT 0 NOT NULL,
    width integer DEFAULT 0 NOT NULL,
    height integer DEFAULT 0 NOT NULL,
    weight integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: spree_product_packages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_product_packages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_product_packages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_product_packages_id_seq OWNED BY spree_product_packages.id;


--
-- Name: spree_product_properties; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_product_properties (
    id identifier NOT NULL,
    value character varying(255),
    product_id identifier,
    property_id identifier,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    "position" integer DEFAULT 0
);


--
-- Name: spree_product_properties_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_product_properties_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_product_properties_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_product_properties_id_seq OWNED BY spree_product_properties.id;


--
-- Name: spree_products_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_products_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_products_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_products_id_seq OWNED BY spree_products.id;


--
-- Name: spree_products_promotion_rules; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_products_promotion_rules (
    product_id identifier,
    promotion_rule_id identifier
);


--
-- Name: spree_products_taxons; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_products_taxons (
    product_id identifier,
    taxon_id identifier,
    id identifier NOT NULL,
    "position" integer
);


--
-- Name: spree_products_taxons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_products_taxons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_products_taxons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_products_taxons_id_seq OWNED BY spree_products_taxons.id;


--
-- Name: spree_promotion_action_line_items; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_promotion_action_line_items (
    id identifier NOT NULL,
    promotion_action_id identifier,
    variant_id identifier,
    quantity integer DEFAULT 1
);


--
-- Name: spree_promotion_action_line_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_promotion_action_line_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_promotion_action_line_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_promotion_action_line_items_id_seq OWNED BY spree_promotion_action_line_items.id;


--
-- Name: spree_promotion_actions; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_promotion_actions (
    id identifier NOT NULL,
    promotion_id identifier,
    "position" integer,
    type character varying(255),
    deleted_at timestamp without time zone
);


--
-- Name: spree_promotion_actions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_promotion_actions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_promotion_actions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_promotion_actions_id_seq OWNED BY spree_promotion_actions.id;


--
-- Name: spree_promotion_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_promotion_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_promotion_categories; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_promotion_categories (
    id identifier DEFAULT nextval('spree_promotion_categories_id_seq'::regclass) NOT NULL,
    name character varying(255) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    CONSTRAINT check_spree_promotion_categories_name CHECK ((char_length((name)::text) >= 1)),
    CONSTRAINT check_spree_promotion_categories_updated_at CHECK ((updated_at >= created_at))
);


--
-- Name: spree_promotion_rules; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_promotion_rules (
    id identifier NOT NULL,
    promotion_id identifier,
    user_id identifier,
    product_group_id identifier,
    type character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    code character varying(255),
    preferences text
);


--
-- Name: spree_promotion_rules_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_promotion_rules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_promotion_rules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_promotion_rules_id_seq OWNED BY spree_promotion_rules.id;


--
-- Name: spree_promotion_rules_users; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_promotion_rules_users (
    user_id identifier,
    promotion_rule_id identifier
);


--
-- Name: spree_promotions; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_promotions (
    id identifier NOT NULL,
    description character varying(255),
    expires_at timestamp without time zone,
    starts_at timestamp without time zone,
    name character varying(255),
    type character varying(255),
    usage_limit integer,
    match_policy character varying(255) DEFAULT 'all'::character varying,
    code character varying(255),
    advertise boolean DEFAULT false,
    path character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    promotion_category_id identifier NOT NULL,
    deleted_at timestamp without time zone,
    CONSTRAINT check_promotions_deleted_at CHECK ((deleted_at >= created_at))
);


--
-- Name: spree_promotions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_promotions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_promotions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_promotions_id_seq OWNED BY spree_promotions.id;


--
-- Name: spree_properties; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_properties (
    id identifier NOT NULL,
    name character varying(255),
    presentation character varying(255) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: spree_properties_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_properties_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_properties_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_properties_id_seq OWNED BY spree_properties.id;


--
-- Name: spree_properties_prototypes; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_properties_prototypes (
    prototype_id identifier,
    property_id identifier
);


--
-- Name: spree_prototypes; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_prototypes (
    id identifier NOT NULL,
    name character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: spree_prototypes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_prototypes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_prototypes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_prototypes_id_seq OWNED BY spree_prototypes.id;


--
-- Name: spree_refund_reasons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_refund_reasons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_refund_reasons; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_refund_reasons (
    id identifier DEFAULT nextval('spree_refund_reasons_id_seq'::regclass) NOT NULL,
    name character varying(255) NOT NULL,
    active boolean DEFAULT true NOT NULL,
    "default" boolean DEFAULT false NOT NULL,
    mutable boolean DEFAULT true NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    CONSTRAINT check_spree_refund_reasons_name CHECK ((char_length((name)::text) >= 1)),
    CONSTRAINT check_spree_refund_reasons_updated_at CHECK ((updated_at >= created_at))
);


--
-- Name: spree_refunds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_refunds_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_refunds; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_refunds (
    id identifier DEFAULT nextval('spree_refunds_id_seq'::regclass) NOT NULL,
    amount numeric_money NOT NULL,
    transaction_id character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    payment_id identifier NOT NULL,
    refund_reason_id identifier NOT NULL,
    reimbursement_id identifier,
    CONSTRAINT check_spree_refunds_amount CHECK (((amount)::numeric > (0)::numeric)),
    CONSTRAINT check_spree_refunds_transaction_id CHECK ((char_length((transaction_id)::text) >= 1)),
    CONSTRAINT check_spree_refunds_updated_at CHECK ((updated_at >= created_at))
);


--
-- Name: spree_reimbursement_credits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_reimbursement_credits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_reimbursement_credits; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_reimbursement_credits (
    id identifier DEFAULT nextval('spree_reimbursement_credits_id_seq'::regclass) NOT NULL,
    amount numeric_money NOT NULL,
    creditable_id identifier NOT NULL,
    creditable_type character varying(255) NOT NULL,
    reimbursement_id identifier NOT NULL
);


--
-- Name: spree_reimbursement_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_reimbursement_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_reimbursement_types; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_reimbursement_types (
    id identifier DEFAULT nextval('spree_reimbursement_types_id_seq'::regclass) NOT NULL,
    name character varying(255) NOT NULL,
    type character varying(255) NOT NULL,
    active boolean DEFAULT true NOT NULL,
    mutable boolean DEFAULT true NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    CONSTRAINT check_spree_reimbursement_types_name CHECK ((char_length((name)::text) >= 1)),
    CONSTRAINT check_spree_reimbursement_types_type CHECK ((char_length((type)::text) >= 1)),
    CONSTRAINT check_spree_reimbursement_types_updated_at CHECK ((updated_at >= created_at))
);


--
-- Name: spree_reimbursements_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_reimbursements_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_reimbursements; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_reimbursements (
    id identifier DEFAULT nextval('spree_reimbursements_id_seq'::regclass) NOT NULL,
    number character varying(11) NOT NULL,
    reimbursement_status character varying(10) NOT NULL,
    total numeric_money,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    order_id identifier NOT NULL,
    customer_return_id identifier,
    CONSTRAINT check_spree_reimbursements_number CHECK ((char_length((number)::text) = 11)),
    CONSTRAINT check_spree_reimbursements_reimbursement_status CHECK (((reimbursement_status)::text = ANY ((ARRAY['reimbursed'::character varying, 'errored'::character varying, 'pending'::character varying])::text[]))),
    CONSTRAINT check_spree_reimbursements_updated_at CHECK ((updated_at >= created_at))
);


--
-- Name: spree_return_authorization_reasons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_return_authorization_reasons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_return_authorization_reasons; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_return_authorization_reasons (
    id identifier DEFAULT nextval('spree_return_authorization_reasons_id_seq'::regclass) NOT NULL,
    name character varying(255) NOT NULL,
    "default" boolean DEFAULT false NOT NULL,
    active boolean DEFAULT true NOT NULL,
    mutable boolean DEFAULT true NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    CONSTRAINT check_spree_return_authorization_reasons_name CHECK ((char_length((name)::text) >= 1)),
    CONSTRAINT check_spree_return_authorization_reasons_updated_at CHECK ((updated_at >= created_at))
);


--
-- Name: spree_return_authorizations; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_return_authorizations (
    id identifier NOT NULL,
    number character varying(255),
    state character varying(255),
    order_id identifier,
    memo text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    stock_location_id identifier,
    return_authorization_reason_id identifier NOT NULL
);


--
-- Name: spree_return_authorizations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_return_authorizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_return_authorizations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_return_authorizations_id_seq OWNED BY spree_return_authorizations.id;


--
-- Name: spree_return_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_return_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_return_items; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_return_items (
    id identifier DEFAULT nextval('spree_return_items_id_seq'::regclass) NOT NULL,
    pre_tax_amount numeric_money DEFAULT 0 NOT NULL,
    included_tax_total numeric_money DEFAULT 0 NOT NULL,
    additional_tax_total numeric_money DEFAULT 0 NOT NULL,
    acceptance_status character varying(28) NOT NULL,
    reception_status character varying(17) NOT NULL,
    acceptance_status_errors text DEFAULT ''::text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    customer_return_id identifier,
    return_authorization_id identifier NOT NULL,
    exchange_inventory_unit_id identifier,
    inventory_unit_id identifier NOT NULL,
    exchange_variant_id identifier,
    preferred_reimbursement_type_id identifier,
    override_reimbursement_type_id identifier,
    reimbursement_id identifier,
    CONSTRAINT check_spree_return_items_acceptance_status CHECK (((acceptance_status)::text = ANY ((ARRAY['pending'::character varying, 'accepted'::character varying, 'rejected'::character varying, 'manual_intervention_required'::character varying])::text[]))),
    CONSTRAINT check_spree_return_items_additional_tax_total CHECK (((additional_tax_total)::numeric >= (0)::numeric)),
    CONSTRAINT check_spree_return_items_included_tax_total CHECK (((included_tax_total)::numeric >= (0)::numeric)),
    CONSTRAINT check_spree_return_items_reception_status CHECK (((reception_status)::text = ANY ((ARRAY['awaiting'::character varying, 'cancelled'::character varying, 'given_to_customer'::character varying, 'received'::character varying])::text[]))),
    CONSTRAINT check_spree_return_items_updated_at CHECK ((updated_at >= created_at))
);


--
-- Name: spree_roles; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_roles (
    id identifier NOT NULL,
    name character varying(255)
);


--
-- Name: spree_roles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_roles_id_seq OWNED BY spree_roles.id;


--
-- Name: spree_roles_users; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_roles_users (
    role_id identifier,
    user_id identifier
);


--
-- Name: spree_shipments; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_shipments (
    id identifier NOT NULL,
    tracking character varying(255),
    number character varying(15) NOT NULL,
    cost numeric_money DEFAULT 0 NOT NULL,
    shipped_at timestamp without time zone,
    order_id identifier,
    address_id identifier,
    state character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    stock_location_id identifier,
    adjustment_total numeric_money DEFAULT 0.0,
    additional_tax_total numeric_money DEFAULT 0 NOT NULL,
    promo_total numeric_money DEFAULT 0 NOT NULL,
    included_tax_total numeric_money DEFAULT 0 NOT NULL,
    pre_tax_amount numeric_money DEFAULT 0 NOT NULL,
    CONSTRAINT check_spree_shipments_additional_tax_total CHECK (((additional_tax_total)::numeric = (0)::numeric)),
    CONSTRAINT check_spree_shipments_cost CHECK (((cost)::numeric >= (0)::numeric)),
    CONSTRAINT check_spree_shipments_included_tax_total CHECK (((included_tax_total)::numeric = (0)::numeric)),
    CONSTRAINT check_spree_shipments_promo_total CHECK (((promo_total)::numeric <= (0)::numeric))
);


--
-- Name: spree_shipments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_shipments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_shipments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_shipments_id_seq OWNED BY spree_shipments.id;


--
-- Name: spree_shipping_categories; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_shipping_categories (
    id identifier NOT NULL,
    name character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: spree_shipping_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_shipping_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_shipping_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_shipping_categories_id_seq OWNED BY spree_shipping_categories.id;


--
-- Name: spree_shipping_method_categories; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_shipping_method_categories (
    id identifier NOT NULL,
    shipping_method_id identifier NOT NULL,
    shipping_category_id identifier NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: spree_shipping_method_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_shipping_method_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_shipping_method_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_shipping_method_categories_id_seq OWNED BY spree_shipping_method_categories.id;


--
-- Name: spree_shipping_methods; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_shipping_methods (
    id identifier NOT NULL,
    name character varying(255),
    display_on character varying(255),
    deleted_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    tracking_url character varying(255),
    admin_name character varying(255),
    tax_category_id identifier,
    code character varying(255)
);


--
-- Name: spree_shipping_methods_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_shipping_methods_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_shipping_methods_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_shipping_methods_id_seq OWNED BY spree_shipping_methods.id;


--
-- Name: spree_shipping_methods_zones; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_shipping_methods_zones (
    shipping_method_id identifier,
    zone_id identifier
);


--
-- Name: spree_shipping_rates; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_shipping_rates (
    id identifier NOT NULL,
    shipment_id identifier,
    shipping_method_id identifier,
    selected boolean DEFAULT false,
    cost numeric_money DEFAULT 0,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    tax_rate_id identifier
);


--
-- Name: spree_shipping_rates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_shipping_rates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_shipping_rates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_shipping_rates_id_seq OWNED BY spree_shipping_rates.id;


--
-- Name: spree_state_changes; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_state_changes (
    id identifier NOT NULL,
    name character varying(255),
    previous_state character varying(255),
    stateful_id identifier,
    user_id identifier,
    stateful_type character varying(255),
    next_state character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    created_by_id identifier
);


--
-- Name: spree_state_changes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_state_changes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_state_changes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_state_changes_id_seq OWNED BY spree_state_changes.id;


--
-- Name: spree_states; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_states (
    id identifier NOT NULL,
    name character varying(30) NOT NULL,
    abbr character(2) NOT NULL,
    country_id identifier NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    CONSTRAINT check_spree_states_abbr CHECK ((char_length(abbr) = 2)),
    CONSTRAINT check_spree_states_name CHECK ((char_length((name)::text) > 0))
);


--
-- Name: spree_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_states_id_seq OWNED BY spree_states.id;


--
-- Name: spree_stock_items; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_stock_items (
    id identifier NOT NULL,
    stock_location_id identifier,
    variant_id identifier,
    count_on_hand integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    backorderable boolean DEFAULT false,
    deleted_at timestamp without time zone
);


--
-- Name: spree_stock_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_stock_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_stock_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_stock_items_id_seq OWNED BY spree_stock_items.id;


--
-- Name: spree_stock_locations; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_stock_locations (
    id identifier NOT NULL,
    name character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    address1 character varying(255),
    address2 character varying(255),
    city character varying(255),
    state_id identifier,
    state_name character varying(255),
    country_id identifier,
    zipcode character varying(255),
    phone character varying(255),
    active boolean DEFAULT true,
    backorderable_default boolean DEFAULT false,
    propagate_all_variants boolean DEFAULT true,
    admin_name character varying(255),
    "default" boolean DEFAULT false NOT NULL
);


--
-- Name: spree_stock_locations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_stock_locations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_stock_locations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_stock_locations_id_seq OWNED BY spree_stock_locations.id;


--
-- Name: spree_stock_movements; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_stock_movements (
    id identifier NOT NULL,
    stock_item_id identifier,
    quantity integer DEFAULT 0,
    action character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    originator_id identifier,
    originator_type character varying(255)
);


--
-- Name: spree_stock_movements_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_stock_movements_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_stock_movements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_stock_movements_id_seq OWNED BY spree_stock_movements.id;


--
-- Name: spree_stock_transfers; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_stock_transfers (
    id identifier NOT NULL,
    type character varying(255),
    reference character varying(255),
    source_location_id identifier,
    destination_location_id identifier,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    number character varying(15) NOT NULL
);


--
-- Name: spree_stock_transfers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_stock_transfers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_stock_transfers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_stock_transfers_id_seq OWNED BY spree_stock_transfers.id;


--
-- Name: spree_stores; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_stores (
    id identifier NOT NULL,
    name character varying(255) NOT NULL,
    url character varying(255) NOT NULL,
    meta_description text,
    meta_keywords text,
    seo_title character varying(255),
    mail_from_address character varying(255) NOT NULL,
    default_currency character varying(255),
    code character varying(255) NOT NULL,
    "default" boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    CONSTRAINT check_spree_stores_code CHECK ((length((code)::text) >= 1)),
    CONSTRAINT check_spree_stores_mail_from_address CHECK ((length((mail_from_address)::text) >= 1)),
    CONSTRAINT check_spree_stores_name CHECK ((length((name)::text) >= 1)),
    CONSTRAINT check_spree_stores_url CHECK ((length((url)::text) >= 1))
);


--
-- Name: spree_stores_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_stores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_stores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_stores_id_seq OWNED BY spree_stores.id;


--
-- Name: spree_tax_categories; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_tax_categories (
    id identifier NOT NULL,
    name character varying(255),
    description character varying(255),
    is_default boolean DEFAULT false,
    deleted_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    tax_code character varying(255)
);


--
-- Name: spree_tax_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_tax_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_tax_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_tax_categories_id_seq OWNED BY spree_tax_categories.id;


--
-- Name: spree_tax_rates; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_tax_rates (
    id identifier NOT NULL,
    amount numeric_money,
    zone_id identifier,
    tax_category_id identifier,
    included_in_price boolean DEFAULT false,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    name character varying(255),
    show_rate_in_label boolean DEFAULT true,
    deleted_at timestamp without time zone
);


--
-- Name: spree_tax_rates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_tax_rates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_tax_rates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_tax_rates_id_seq OWNED BY spree_tax_rates.id;


--
-- Name: spree_taxonomies; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_taxonomies (
    id identifier NOT NULL,
    name character varying(255) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    "position" integer DEFAULT 0
);


--
-- Name: spree_taxonomies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_taxonomies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_taxonomies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_taxonomies_id_seq OWNED BY spree_taxonomies.id;


--
-- Name: spree_taxons; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_taxons (
    id identifier NOT NULL,
    parent_id identifier,
    "position" integer DEFAULT 0,
    name character varying(255) NOT NULL,
    permalink character varying(255),
    taxonomy_id identifier,
    lft integer,
    rgt integer,
    icon_file_name character varying(255),
    icon_content_type character varying(255),
    icon_file_size integer,
    icon_updated_at timestamp without time zone,
    description text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    meta_title character varying(255),
    meta_description character varying(255),
    meta_keywords character varying(255),
    depth integer
);


--
-- Name: spree_taxons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_taxons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_taxons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_taxons_id_seq OWNED BY spree_taxons.id;


--
-- Name: spree_taxons_promotion_rules_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_taxons_promotion_rules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_taxons_promotion_rules; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_taxons_promotion_rules (
    id identifier DEFAULT nextval('spree_taxons_promotion_rules_id_seq'::regclass) NOT NULL,
    taxon_id identifier NOT NULL,
    promotion_rule_id identifier NOT NULL
);


--
-- Name: spree_taxons_prototypes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_taxons_prototypes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_taxons_prototypes; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_taxons_prototypes (
    id identifier DEFAULT nextval('spree_taxons_prototypes_id_seq'::regclass) NOT NULL,
    taxon_id identifier NOT NULL,
    prototype_id identifier NOT NULL
);


--
-- Name: spree_tokenized_permissions; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_tokenized_permissions (
    id identifier NOT NULL,
    permissable_id identifier,
    permissable_type character varying(255),
    token character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: spree_tokenized_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_tokenized_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_tokenized_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_tokenized_permissions_id_seq OWNED BY spree_tokenized_permissions.id;


--
-- Name: spree_trackers; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_trackers (
    id identifier NOT NULL,
    environment character varying(255),
    analytics_id character varying(255),
    active boolean DEFAULT true,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: spree_trackers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_trackers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_trackers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_trackers_id_seq OWNED BY spree_trackers.id;


--
-- Name: spree_users; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_users (
    id identifier NOT NULL,
    encrypted_password character varying(128),
    password_salt character varying(128),
    email character varying(255),
    remember_token character varying(255),
    persistence_token character varying(255),
    reset_password_token character varying(255),
    perishable_token character varying(255),
    sign_in_count integer DEFAULT 0 NOT NULL,
    failed_attempts integer DEFAULT 0 NOT NULL,
    last_request_at timestamp without time zone,
    current_sign_in_at timestamp without time zone,
    last_sign_in_at timestamp without time zone,
    current_sign_in_ip character varying(255),
    last_sign_in_ip character varying(255),
    login character varying(255),
    ship_address_id identifier,
    bill_address_id identifier,
    authentication_token character varying(255),
    unlock_token character varying(255),
    locked_at timestamp without time zone,
    reset_password_sent_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    spree_api_key character varying(48),
    remember_created_at timestamp without time zone,
    confirmation_token character varying(255),
    confirmation_sent_at timestamp without time zone,
    confirmed_at timestamp without time zone,
    deleted_at timestamp without time zone,
    CONSTRAINT check_spree_users_confirmation_sent_at CHECK ((confirmation_sent_at IS NULL)),
    CONSTRAINT check_spree_users_confirmation_token CHECK ((confirmation_token IS NULL)),
    CONSTRAINT check_spree_users_confirmed_at CHECK ((confirmed_at IS NULL)),
    CONSTRAINT check_spree_users_deleted_at CHECK ((deleted_at >= created_at)),
    CONSTRAINT check_spree_users_remember_created_at CHECK ((remember_created_at >= created_at))
);


--
-- Name: spree_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_users_id_seq OWNED BY spree_users.id;


--
-- Name: spree_variants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_variants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_variants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_variants_id_seq OWNED BY spree_variants.id;


--
-- Name: spree_zone_members; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_zone_members (
    id identifier NOT NULL,
    zoneable_id identifier,
    zoneable_type character varying(255),
    zone_id identifier,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: spree_zone_members_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_zone_members_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_zone_members_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_zone_members_id_seq OWNED BY spree_zone_members.id;


--
-- Name: spree_zones; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE spree_zones (
    id identifier NOT NULL,
    name character varying(255) NOT NULL,
    description character varying(255),
    default_tax boolean DEFAULT false,
    zone_members_count integer DEFAULT 0,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    CONSTRAINT check_spree_zones_description CHECK ((char_length((description)::text) >= 1)),
    CONSTRAINT check_spree_zones_name CHECK ((char_length((name)::text) >= 1)),
    CONSTRAINT check_spree_zones_updated_at CHECK ((updated_at >= created_at)),
    CONSTRAINT check_spree_zones_zone_members_count CHECK ((zone_members_count >= 0))
);


--
-- Name: spree_zones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE spree_zones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_zones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE spree_zones_id_seq OWNED BY spree_zones.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_addresses ALTER COLUMN id SET DEFAULT nextval('spree_addresses_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_adjustments ALTER COLUMN id SET DEFAULT nextval('spree_adjustments_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_assets ALTER COLUMN id SET DEFAULT nextval('spree_assets_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_calculators ALTER COLUMN id SET DEFAULT nextval('spree_calculators_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_configurations ALTER COLUMN id SET DEFAULT nextval('spree_configurations_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_countries ALTER COLUMN id SET DEFAULT nextval('spree_countries_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_credit_cards ALTER COLUMN id SET DEFAULT nextval('spree_credit_cards_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_gateways ALTER COLUMN id SET DEFAULT nextval('spree_gateways_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_inventory_units ALTER COLUMN id SET DEFAULT nextval('spree_inventory_units_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_line_items ALTER COLUMN id SET DEFAULT nextval('spree_line_items_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_log_entries ALTER COLUMN id SET DEFAULT nextval('spree_log_entries_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_new_adjustments ALTER COLUMN id SET DEFAULT nextval('spree_new_adjustments_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_option_types ALTER COLUMN id SET DEFAULT nextval('spree_option_types_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_option_values ALTER COLUMN id SET DEFAULT nextval('spree_option_values_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_orders ALTER COLUMN id SET DEFAULT nextval('spree_orders_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_payment_capture_events ALTER COLUMN id SET DEFAULT nextval('spree_payment_capture_events_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_payment_methods ALTER COLUMN id SET DEFAULT nextval('spree_payment_methods_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_payments ALTER COLUMN id SET DEFAULT nextval('spree_payments_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_preferences ALTER COLUMN id SET DEFAULT nextval('spree_preferences_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_prices ALTER COLUMN id SET DEFAULT nextval('spree_prices_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_product_option_types ALTER COLUMN id SET DEFAULT nextval('spree_product_option_types_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_product_packages ALTER COLUMN id SET DEFAULT nextval('spree_product_packages_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_product_properties ALTER COLUMN id SET DEFAULT nextval('spree_product_properties_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_products ALTER COLUMN id SET DEFAULT nextval('spree_products_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_products_taxons ALTER COLUMN id SET DEFAULT nextval('spree_products_taxons_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_promotion_action_line_items ALTER COLUMN id SET DEFAULT nextval('spree_promotion_action_line_items_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_promotion_actions ALTER COLUMN id SET DEFAULT nextval('spree_promotion_actions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_promotion_rules ALTER COLUMN id SET DEFAULT nextval('spree_promotion_rules_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_promotions ALTER COLUMN id SET DEFAULT nextval('spree_promotions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_properties ALTER COLUMN id SET DEFAULT nextval('spree_properties_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_prototypes ALTER COLUMN id SET DEFAULT nextval('spree_prototypes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_return_authorizations ALTER COLUMN id SET DEFAULT nextval('spree_return_authorizations_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_roles ALTER COLUMN id SET DEFAULT nextval('spree_roles_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_shipments ALTER COLUMN id SET DEFAULT nextval('spree_shipments_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_shipping_categories ALTER COLUMN id SET DEFAULT nextval('spree_shipping_categories_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_shipping_method_categories ALTER COLUMN id SET DEFAULT nextval('spree_shipping_method_categories_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_shipping_methods ALTER COLUMN id SET DEFAULT nextval('spree_shipping_methods_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_shipping_rates ALTER COLUMN id SET DEFAULT nextval('spree_shipping_rates_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_state_changes ALTER COLUMN id SET DEFAULT nextval('spree_state_changes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_states ALTER COLUMN id SET DEFAULT nextval('spree_states_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_stock_items ALTER COLUMN id SET DEFAULT nextval('spree_stock_items_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_stock_locations ALTER COLUMN id SET DEFAULT nextval('spree_stock_locations_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_stock_movements ALTER COLUMN id SET DEFAULT nextval('spree_stock_movements_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_stock_transfers ALTER COLUMN id SET DEFAULT nextval('spree_stock_transfers_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_stores ALTER COLUMN id SET DEFAULT nextval('spree_stores_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_tax_categories ALTER COLUMN id SET DEFAULT nextval('spree_tax_categories_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_tax_rates ALTER COLUMN id SET DEFAULT nextval('spree_tax_rates_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_taxonomies ALTER COLUMN id SET DEFAULT nextval('spree_taxonomies_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_taxons ALTER COLUMN id SET DEFAULT nextval('spree_taxons_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_tokenized_permissions ALTER COLUMN id SET DEFAULT nextval('spree_tokenized_permissions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_trackers ALTER COLUMN id SET DEFAULT nextval('spree_trackers_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_users ALTER COLUMN id SET DEFAULT nextval('spree_users_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_variants ALTER COLUMN id SET DEFAULT nextval('spree_variants_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_zone_members ALTER COLUMN id SET DEFAULT nextval('spree_zone_members_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_zones ALTER COLUMN id SET DEFAULT nextval('spree_zones_id_seq'::regclass);


--
-- Name: friendly_id_slugs_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY friendly_id_slugs
    ADD CONSTRAINT friendly_id_slugs_pkey PRIMARY KEY (id);


--
-- Name: index_spree_countries_on_iso3_and_name; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_countries
    ADD CONSTRAINT index_spree_countries_on_iso3_and_name UNIQUE (iso3, name);


--
-- Name: index_spree_countries_on_iso_and_name; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_countries
    ADD CONSTRAINT index_spree_countries_on_iso_and_name UNIQUE (iso, name);


--
-- Name: index_spree_countries_on_iso_name_and_name; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_countries
    ADD CONSTRAINT index_spree_countries_on_iso_name_and_name UNIQUE (iso_name, name);


--
-- Name: index_spree_countries_on_name; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_countries
    ADD CONSTRAINT index_spree_countries_on_name UNIQUE (name);


--
-- Name: index_spree_countries_on_numcode_and_name; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_countries
    ADD CONSTRAINT index_spree_countries_on_numcode_and_name UNIQUE (numcode, name);


--
-- Name: index_spree_states_on_abbr_and_country_id; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_states
    ADD CONSTRAINT index_spree_states_on_abbr_and_country_id UNIQUE (abbr, country_id);


--
-- Name: index_spree_states_on_name_and_country_id; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_states
    ADD CONSTRAINT index_spree_states_on_name_and_country_id UNIQUE (name, country_id);


--
-- Name: spree_activators_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_promotions
    ADD CONSTRAINT spree_activators_pkey PRIMARY KEY (id);


--
-- Name: spree_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_addresses
    ADD CONSTRAINT spree_addresses_pkey PRIMARY KEY (id);


--
-- Name: spree_adjustments_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_adjustments
    ADD CONSTRAINT spree_adjustments_pkey PRIMARY KEY (id);


--
-- Name: spree_assets_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_assets
    ADD CONSTRAINT spree_assets_pkey PRIMARY KEY (id);


--
-- Name: spree_calculators_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_calculators
    ADD CONSTRAINT spree_calculators_pkey PRIMARY KEY (id);


--
-- Name: spree_configurations_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_configurations
    ADD CONSTRAINT spree_configurations_pkey PRIMARY KEY (id);


--
-- Name: spree_countries_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_countries
    ADD CONSTRAINT spree_countries_pkey PRIMARY KEY (id);


--
-- Name: spree_credit_cards_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_credit_cards
    ADD CONSTRAINT spree_credit_cards_pkey PRIMARY KEY (id);


--
-- Name: spree_customer_returns_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_customer_returns
    ADD CONSTRAINT spree_customer_returns_pkey PRIMARY KEY (id);


--
-- Name: spree_gateways_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_gateways
    ADD CONSTRAINT spree_gateways_pkey PRIMARY KEY (id);


--
-- Name: spree_inventory_units_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_inventory_units
    ADD CONSTRAINT spree_inventory_units_pkey PRIMARY KEY (id);


--
-- Name: spree_line_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_line_items
    ADD CONSTRAINT spree_line_items_pkey PRIMARY KEY (id);


--
-- Name: spree_log_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_log_entries
    ADD CONSTRAINT spree_log_entries_pkey PRIMARY KEY (id);


--
-- Name: spree_new_adjustments_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_new_adjustments
    ADD CONSTRAINT spree_new_adjustments_pkey PRIMARY KEY (id);


--
-- Name: spree_option_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_option_types
    ADD CONSTRAINT spree_option_types_pkey PRIMARY KEY (id);


--
-- Name: spree_option_values_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_option_values
    ADD CONSTRAINT spree_option_values_pkey PRIMARY KEY (id);


--
-- Name: spree_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_orders
    ADD CONSTRAINT spree_orders_pkey PRIMARY KEY (id);


--
-- Name: spree_payment_capture_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_payment_capture_events
    ADD CONSTRAINT spree_payment_capture_events_pkey PRIMARY KEY (id);


--
-- Name: spree_payment_methods_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_payment_methods
    ADD CONSTRAINT spree_payment_methods_pkey PRIMARY KEY (id);


--
-- Name: spree_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_payments
    ADD CONSTRAINT spree_payments_pkey PRIMARY KEY (id);


--
-- Name: spree_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_preferences
    ADD CONSTRAINT spree_preferences_pkey PRIMARY KEY (id);


--
-- Name: spree_prices_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_prices
    ADD CONSTRAINT spree_prices_pkey PRIMARY KEY (id);


--
-- Name: spree_product_option_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_product_option_types
    ADD CONSTRAINT spree_product_option_types_pkey PRIMARY KEY (id);


--
-- Name: spree_product_packages_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_product_packages
    ADD CONSTRAINT spree_product_packages_pkey PRIMARY KEY (id);


--
-- Name: spree_product_properties_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_product_properties
    ADD CONSTRAINT spree_product_properties_pkey PRIMARY KEY (id);


--
-- Name: spree_products_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_products
    ADD CONSTRAINT spree_products_pkey PRIMARY KEY (id);


--
-- Name: spree_products_taxons_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_products_taxons
    ADD CONSTRAINT spree_products_taxons_pkey PRIMARY KEY (id);


--
-- Name: spree_promotion_action_line_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_promotion_action_line_items
    ADD CONSTRAINT spree_promotion_action_line_items_pkey PRIMARY KEY (id);


--
-- Name: spree_promotion_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_promotion_actions
    ADD CONSTRAINT spree_promotion_actions_pkey PRIMARY KEY (id);


--
-- Name: spree_promotion_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_promotion_categories
    ADD CONSTRAINT spree_promotion_categories_pkey PRIMARY KEY (id);


--
-- Name: spree_promotion_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_promotion_rules
    ADD CONSTRAINT spree_promotion_rules_pkey PRIMARY KEY (id);


--
-- Name: spree_properties_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_properties
    ADD CONSTRAINT spree_properties_pkey PRIMARY KEY (id);


--
-- Name: spree_prototypes_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_prototypes
    ADD CONSTRAINT spree_prototypes_pkey PRIMARY KEY (id);


--
-- Name: spree_refund_reasons_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_refund_reasons
    ADD CONSTRAINT spree_refund_reasons_pkey PRIMARY KEY (id);


--
-- Name: spree_refunds_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_refunds
    ADD CONSTRAINT spree_refunds_pkey PRIMARY KEY (id);


--
-- Name: spree_reimbursement_credits_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_reimbursement_credits
    ADD CONSTRAINT spree_reimbursement_credits_pkey PRIMARY KEY (id);


--
-- Name: spree_reimbursement_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_reimbursement_types
    ADD CONSTRAINT spree_reimbursement_types_pkey PRIMARY KEY (id);


--
-- Name: spree_reimbursements_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_reimbursements
    ADD CONSTRAINT spree_reimbursements_pkey PRIMARY KEY (id);


--
-- Name: spree_return_authorization_reasons_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_return_authorization_reasons
    ADD CONSTRAINT spree_return_authorization_reasons_pkey PRIMARY KEY (id);


--
-- Name: spree_return_authorizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_return_authorizations
    ADD CONSTRAINT spree_return_authorizations_pkey PRIMARY KEY (id);


--
-- Name: spree_return_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_return_items
    ADD CONSTRAINT spree_return_items_pkey PRIMARY KEY (id);


--
-- Name: spree_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_roles
    ADD CONSTRAINT spree_roles_pkey PRIMARY KEY (id);


--
-- Name: spree_shipments_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_shipments
    ADD CONSTRAINT spree_shipments_pkey PRIMARY KEY (id);


--
-- Name: spree_shipping_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_shipping_categories
    ADD CONSTRAINT spree_shipping_categories_pkey PRIMARY KEY (id);


--
-- Name: spree_shipping_method_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_shipping_method_categories
    ADD CONSTRAINT spree_shipping_method_categories_pkey PRIMARY KEY (id);


--
-- Name: spree_shipping_methods_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_shipping_methods
    ADD CONSTRAINT spree_shipping_methods_pkey PRIMARY KEY (id);


--
-- Name: spree_shipping_rates_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_shipping_rates
    ADD CONSTRAINT spree_shipping_rates_pkey PRIMARY KEY (id);


--
-- Name: spree_state_changes_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_state_changes
    ADD CONSTRAINT spree_state_changes_pkey PRIMARY KEY (id);


--
-- Name: spree_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_states
    ADD CONSTRAINT spree_states_pkey PRIMARY KEY (id);


--
-- Name: spree_stock_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_stock_items
    ADD CONSTRAINT spree_stock_items_pkey PRIMARY KEY (id);


--
-- Name: spree_stock_locations_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_stock_locations
    ADD CONSTRAINT spree_stock_locations_pkey PRIMARY KEY (id);


--
-- Name: spree_stock_movements_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_stock_movements
    ADD CONSTRAINT spree_stock_movements_pkey PRIMARY KEY (id);


--
-- Name: spree_stock_transfers_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_stock_transfers
    ADD CONSTRAINT spree_stock_transfers_pkey PRIMARY KEY (id);


--
-- Name: spree_stores_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_stores
    ADD CONSTRAINT spree_stores_pkey PRIMARY KEY (id);


--
-- Name: spree_tax_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_tax_categories
    ADD CONSTRAINT spree_tax_categories_pkey PRIMARY KEY (id);


--
-- Name: spree_tax_rates_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_tax_rates
    ADD CONSTRAINT spree_tax_rates_pkey PRIMARY KEY (id);


--
-- Name: spree_taxonomies_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_taxonomies
    ADD CONSTRAINT spree_taxonomies_pkey PRIMARY KEY (id);


--
-- Name: spree_taxons_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_taxons
    ADD CONSTRAINT spree_taxons_pkey PRIMARY KEY (id);


--
-- Name: spree_taxons_promotion_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_taxons_promotion_rules
    ADD CONSTRAINT spree_taxons_promotion_rules_pkey PRIMARY KEY (id);


--
-- Name: spree_taxons_prototypes_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_taxons_prototypes
    ADD CONSTRAINT spree_taxons_prototypes_pkey PRIMARY KEY (id);


--
-- Name: spree_tokenized_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_tokenized_permissions
    ADD CONSTRAINT spree_tokenized_permissions_pkey PRIMARY KEY (id);


--
-- Name: spree_trackers_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_trackers
    ADD CONSTRAINT spree_trackers_pkey PRIMARY KEY (id);


--
-- Name: spree_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_users
    ADD CONSTRAINT spree_users_pkey PRIMARY KEY (id);


--
-- Name: spree_variants_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_variants
    ADD CONSTRAINT spree_variants_pkey PRIMARY KEY (id);


--
-- Name: spree_zone_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_zone_members
    ADD CONSTRAINT spree_zone_members_pkey PRIMARY KEY (id);


--
-- Name: spree_zones_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_zones
    ADD CONSTRAINT spree_zones_pkey PRIMARY KEY (id);


--
-- Name: unique_spree_option_types_on_name; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_option_types
    ADD CONSTRAINT unique_spree_option_types_on_name UNIQUE (name);


--
-- Name: unique_spree_option_types_on_position; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_option_types
    ADD CONSTRAINT unique_spree_option_types_on_position UNIQUE ("position") DEFERRABLE INITIALLY DEFERRED;


--
-- Name: unique_spree_option_types_on_presentation; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_option_types
    ADD CONSTRAINT unique_spree_option_types_on_presentation UNIQUE (presentation);


--
-- Name: unique_spree_zones_on_description; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_zones
    ADD CONSTRAINT unique_spree_zones_on_description UNIQUE (description);


--
-- Name: unique_spree_zones_on_name; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace:
--

ALTER TABLE ONLY spree_zones
    ADD CONSTRAINT unique_spree_zones_on_name UNIQUE (name);


--
-- Name: index_friendly_id_slugs_on_deleted_at; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_friendly_id_slugs_on_deleted_at ON friendly_id_slugs USING btree (deleted_at);


--
-- Name: index_friendly_id_slugs_on_sluggable_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_friendly_id_slugs_on_sluggable_id ON friendly_id_slugs USING btree (sluggable_id);


--
-- Name: index_friendly_id_slugs_on_sluggable_type; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_friendly_id_slugs_on_sluggable_type ON friendly_id_slugs USING btree (sluggable_type);


--
-- Name: index_return_authorizations_on_return_authorization_reason_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX index_return_authorizations_on_return_authorization_reason_id ON spree_return_authorizations USING btree (return_authorization_reason_id);


--
-- Name: INDEX index_return_authorizations_on_return_authorization_reason_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON INDEX index_return_authorizations_on_return_authorization_reason_id IS 'Full name would be index_spree_return_authorizations_on_return_authorization_reason_id, but this overruns 63 character maximums';


--
-- Name: index_spree_addresses_on_country_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_addresses_on_country_id ON spree_addresses USING btree (country_id);


--
-- Name: index_spree_addresses_on_firstname; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_addresses_on_firstname ON spree_addresses USING btree (firstname);


--
-- Name: index_spree_addresses_on_lastname; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_addresses_on_lastname ON spree_addresses USING btree (lastname);


--
-- Name: index_spree_addresses_on_state_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_addresses_on_state_id ON spree_addresses USING btree (state_id);


--
-- Name: index_spree_adjustments_on_adjustable_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_adjustments_on_adjustable_id ON spree_adjustments USING btree (adjustable_id);


--
-- Name: index_spree_adjustments_on_adjustable_id_adjustable_type; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_adjustments_on_adjustable_id_adjustable_type ON spree_adjustments USING btree (adjustable_id, adjustable_type);


--
-- Name: index_spree_adjustments_on_eligible; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_adjustments_on_eligible ON spree_adjustments USING btree (eligible);


--
-- Name: index_spree_adjustments_on_order_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_adjustments_on_order_id ON spree_adjustments USING btree (order_id);


--
-- Name: index_spree_adjustments_on_source_id_source_type; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_adjustments_on_source_id_source_type ON spree_adjustments USING btree (source_id, source_type);


--
-- Name: index_spree_assets_on_viewable_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_assets_on_viewable_id ON spree_assets USING btree (viewable_id);


--
-- Name: index_spree_assets_on_viewable_type_type; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_assets_on_viewable_type_type ON spree_assets USING btree (viewable_type, type);


--
-- Name: index_spree_calculators_on_calculable_id_calculable_type; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_calculators_on_calculable_id_calculable_type ON spree_calculators USING btree (calculable_id, calculable_type);


--
-- Name: index_spree_calculators_on_id_type; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_calculators_on_id_type ON spree_calculators USING btree (id, type);


--
-- Name: index_spree_configurations_on_name_type; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_configurations_on_name_type ON spree_configurations USING btree (name, type);


--
-- Name: index_spree_credit_cards_on_address_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_credit_cards_on_address_id ON spree_credit_cards USING btree (address_id);


--
-- Name: index_spree_credit_cards_on_payment_method_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_credit_cards_on_payment_method_id ON spree_credit_cards USING btree (payment_method_id);


--
-- Name: index_spree_credit_cards_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_credit_cards_on_user_id ON spree_credit_cards USING btree (user_id);


--
-- Name: index_spree_customer_returns_on_stock_location_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_customer_returns_on_stock_location_id ON spree_customer_returns USING btree (stock_location_id);


--
-- Name: index_spree_gateways_on_active; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_gateways_on_active ON spree_gateways USING btree (active);


--
-- Name: index_spree_gateways_on_test_mode; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_gateways_on_test_mode ON spree_gateways USING btree (test_mode);


--
-- Name: index_spree_inventory_units_on_line_item_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_inventory_units_on_line_item_id ON spree_inventory_units USING btree (line_item_id);


--
-- Name: index_spree_inventory_units_on_order_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_inventory_units_on_order_id ON spree_inventory_units USING btree (order_id);


--
-- Name: index_spree_inventory_units_on_return_authorization_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_inventory_units_on_return_authorization_id ON spree_inventory_units USING btree (return_authorization_id);


--
-- Name: index_spree_inventory_units_on_shipment_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_inventory_units_on_shipment_id ON spree_inventory_units USING btree (shipment_id);


--
-- Name: index_spree_inventory_units_on_variant_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_inventory_units_on_variant_id ON spree_inventory_units USING btree (variant_id);


--
-- Name: index_spree_line_items_on_order_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_line_items_on_order_id ON spree_line_items USING btree (order_id);


--
-- Name: index_spree_line_items_on_tax_category_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_line_items_on_tax_category_id ON spree_line_items USING btree (tax_category_id);


--
-- Name: index_spree_log_entries_on_source_id_source_type; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_log_entries_on_source_id_source_type ON spree_log_entries USING btree (source_id, source_type);


--
-- Name: index_spree_option_values_on_option_type_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_option_values_on_option_type_id ON spree_option_values USING btree (option_type_id);


--
-- Name: index_spree_option_values_on_position; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_option_values_on_position ON spree_option_values USING btree ("position");


--
-- Name: index_spree_option_values_variants_on_variant_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_option_values_variants_on_variant_id ON spree_option_values_variants USING btree (variant_id);


--
-- Name: index_spree_option_values_variants_on_variant_id_option_value_i; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_option_values_variants_on_variant_id_option_value_i ON spree_option_values_variants USING btree (variant_id, option_value_id);


--
-- Name: index_spree_orders_on_approver_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_orders_on_approver_id ON spree_orders USING btree (approver_id);


--
-- Name: index_spree_orders_on_bill_address_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_orders_on_bill_address_id ON spree_orders USING btree (bill_address_id);


--
-- Name: index_spree_orders_on_completed_at; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_orders_on_completed_at ON spree_orders USING btree (completed_at);


--
-- Name: index_spree_orders_on_confirmation_delivered; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_orders_on_confirmation_delivered ON spree_orders USING btree (confirmation_delivered);


--
-- Name: index_spree_orders_on_considered_risky; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_orders_on_considered_risky ON spree_orders USING btree (considered_risky);


--
-- Name: index_spree_orders_on_created_by_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_orders_on_created_by_id ON spree_orders USING btree (created_by_id);


--
-- Name: index_spree_orders_on_guest_token; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_orders_on_guest_token ON spree_orders USING btree (guest_token);


--
-- Name: index_spree_orders_on_ship_address_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_orders_on_ship_address_id ON spree_orders USING btree (ship_address_id);


--
-- Name: index_spree_orders_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_orders_on_user_id ON spree_orders USING btree (user_id);


--
-- Name: index_spree_orders_on_user_id_created_by_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_orders_on_user_id_created_by_id ON spree_orders USING btree (user_id, created_by_id);


--
-- Name: index_spree_orders_promotions_on_order_id_promotion_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_orders_promotions_on_order_id_promotion_id ON spree_orders_promotions USING btree (order_id, promotion_id);


--
-- Name: index_spree_payment_capture_events_on_payment_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_payment_capture_events_on_payment_id ON spree_payment_capture_events USING btree (payment_id);


--
-- Name: index_spree_payment_methods_on_deleted_at_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_payment_methods_on_deleted_at_id ON spree_payment_methods USING btree (deleted_at, id);


--
-- Name: index_spree_payment_methods_on_id_type; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_payment_methods_on_id_type ON spree_payment_methods USING btree (id, type);


--
-- Name: index_spree_payments_on_order_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_payments_on_order_id ON spree_payments USING btree (order_id);


--
-- Name: index_spree_payments_on_payment_method_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_payments_on_payment_method_id ON spree_payments USING btree (payment_method_id);


--
-- Name: index_spree_payments_on_source_id_source_type; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_payments_on_source_id_source_type ON spree_payments USING btree (source_id, source_type);


--
-- Name: index_spree_prices_on_deleted_at_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_prices_on_deleted_at_id ON spree_prices USING btree (deleted_at, id);


--
-- Name: index_spree_prices_on_variant_id_currency; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_prices_on_variant_id_currency ON spree_prices USING btree (variant_id, currency);


--
-- Name: index_spree_product_option_types_on_option_type_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_product_option_types_on_option_type_id ON spree_product_option_types USING btree (option_type_id);


--
-- Name: index_spree_product_option_types_on_position; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_product_option_types_on_position ON spree_product_option_types USING btree ("position");


--
-- Name: index_spree_product_option_types_on_product_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_product_option_types_on_product_id ON spree_product_option_types USING btree (product_id);


--
-- Name: index_spree_product_properties_on_position; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_product_properties_on_position ON spree_product_properties USING btree ("position");


--
-- Name: index_spree_product_properties_on_product_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_product_properties_on_product_id ON spree_product_properties USING btree (product_id);


--
-- Name: index_spree_product_properties_on_property_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_product_properties_on_property_id ON spree_product_properties USING btree (property_id);


--
-- Name: index_spree_products_on_available_on; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_products_on_available_on ON spree_products USING btree (available_on);


--
-- Name: index_spree_products_on_deleted_at_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_products_on_deleted_at_id ON spree_products USING btree (deleted_at, id);


--
-- Name: index_spree_products_on_shipping_category_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_products_on_shipping_category_id ON spree_products USING btree (shipping_category_id);


--
-- Name: index_spree_products_on_tax_category_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_products_on_tax_category_id ON spree_products USING btree (tax_category_id);


--
-- Name: index_spree_products_promotion_rules_on_product_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_products_promotion_rules_on_product_id ON spree_products_promotion_rules USING btree (product_id);


--
-- Name: index_spree_products_promotion_rules_on_promotion_rule_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_products_promotion_rules_on_promotion_rule_id ON spree_products_promotion_rules USING btree (promotion_rule_id);


--
-- Name: index_spree_products_taxons_on_position; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_products_taxons_on_position ON spree_products_taxons USING btree ("position");


--
-- Name: index_spree_products_taxons_on_product_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_products_taxons_on_product_id ON spree_products_taxons USING btree (product_id);


--
-- Name: index_spree_products_taxons_on_taxon_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_products_taxons_on_taxon_id ON spree_products_taxons USING btree (taxon_id);


--
-- Name: index_spree_promotion_action_line_items_on_promotion_action_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_promotion_action_line_items_on_promotion_action_id ON spree_promotion_action_line_items USING btree (promotion_action_id);


--
-- Name: index_spree_promotion_action_line_items_on_variant_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_promotion_action_line_items_on_variant_id ON spree_promotion_action_line_items USING btree (variant_id);


--
-- Name: index_spree_promotion_actions_on_deleted_at_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_promotion_actions_on_deleted_at_id ON spree_promotion_actions USING btree (deleted_at, id);


--
-- Name: index_spree_promotion_actions_on_id_type; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_promotion_actions_on_id_type ON spree_promotion_actions USING btree (id, type);


--
-- Name: index_spree_promotion_actions_on_promotion_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_promotion_actions_on_promotion_id ON spree_promotion_actions USING btree (promotion_id);


--
-- Name: index_spree_promotion_rules_on_product_group_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_promotion_rules_on_product_group_id ON spree_promotion_rules USING btree (product_group_id);


--
-- Name: index_spree_promotion_rules_on_promotion_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_promotion_rules_on_promotion_id ON spree_promotion_rules USING btree (promotion_id);


--
-- Name: index_spree_promotion_rules_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_promotion_rules_on_user_id ON spree_promotion_rules USING btree (user_id);


--
-- Name: index_spree_promotion_rules_users_on_promotion_rule_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_promotion_rules_users_on_promotion_rule_id ON spree_promotion_rules_users USING btree (promotion_rule_id);


--
-- Name: index_spree_promotion_rules_users_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_promotion_rules_users_on_user_id ON spree_promotion_rules_users USING btree (user_id);


--
-- Name: index_spree_promotions_on_advertise; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_promotions_on_advertise ON spree_promotions USING btree (advertise);


--
-- Name: index_spree_promotions_on_code; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_promotions_on_code ON spree_promotions USING btree (code);


--
-- Name: index_spree_promotions_on_expires_at; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_promotions_on_expires_at ON spree_promotions USING btree (expires_at);


--
-- Name: index_spree_promotions_on_id_type; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_promotions_on_id_type ON spree_promotions USING btree (id, type);


--
-- Name: index_spree_promotions_on_promotion_category_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_promotions_on_promotion_category_id ON spree_promotions USING btree (promotion_category_id);


--
-- Name: index_spree_promotions_on_starts_at; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_promotions_on_starts_at ON spree_promotions USING btree (starts_at);


--
-- Name: index_spree_refunds_on_payment_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_refunds_on_payment_id ON spree_refunds USING btree (payment_id);


--
-- Name: index_spree_refunds_on_refund_reason_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_refunds_on_refund_reason_id ON spree_refunds USING btree (refund_reason_id);


--
-- Name: index_spree_refunds_on_reimbursement_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_refunds_on_reimbursement_id ON spree_refunds USING btree (reimbursement_id);


--
-- Name: index_spree_reimbursement_credits_on_reimbursement_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_reimbursement_credits_on_reimbursement_id ON spree_reimbursement_credits USING btree (reimbursement_id);


--
-- Name: index_spree_reimbursements_on_customer_return_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_reimbursements_on_customer_return_id ON spree_reimbursements USING btree (customer_return_id);


--
-- Name: index_spree_return_authorizations_on_number; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_return_authorizations_on_number ON spree_return_authorizations USING btree (number);


--
-- Name: index_spree_return_authorizations_on_order_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_return_authorizations_on_order_id ON spree_return_authorizations USING btree (order_id);


--
-- Name: index_spree_return_authorizations_on_stock_location_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_return_authorizations_on_stock_location_id ON spree_return_authorizations USING btree (stock_location_id);


--
-- Name: index_spree_return_items_on_customer_return_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_return_items_on_customer_return_id ON spree_return_items USING btree (customer_return_id);


--
-- Name: index_spree_return_items_on_exchange_inventory_unit_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_return_items_on_exchange_inventory_unit_id ON spree_return_items USING btree (exchange_inventory_unit_id);


--
-- Name: index_spree_return_items_on_exchange_variant_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_return_items_on_exchange_variant_id ON spree_return_items USING btree (exchange_variant_id);


--
-- Name: index_spree_return_items_on_inventory_unit_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_return_items_on_inventory_unit_id ON spree_return_items USING btree (inventory_unit_id);


--
-- Name: index_spree_return_items_on_override_reimbursement_type_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_return_items_on_override_reimbursement_type_id ON spree_return_items USING btree (override_reimbursement_type_id);


--
-- Name: index_spree_return_items_on_preferred_reimbursement_type_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_return_items_on_preferred_reimbursement_type_id ON spree_return_items USING btree (preferred_reimbursement_type_id);


--
-- Name: index_spree_return_items_on_reimbursement_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_return_items_on_reimbursement_id ON spree_return_items USING btree (reimbursement_id);


--
-- Name: index_spree_return_items_on_return_authorization_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_return_items_on_return_authorization_id ON spree_return_items USING btree (return_authorization_id);


--
-- Name: index_spree_roles_users_on_role_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_roles_users_on_role_id ON spree_roles_users USING btree (role_id);


--
-- Name: index_spree_roles_users_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_roles_users_on_user_id ON spree_roles_users USING btree (user_id);


--
-- Name: index_spree_shipments_on_address_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_shipments_on_address_id ON spree_shipments USING btree (address_id);


--
-- Name: index_spree_shipments_on_order_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_shipments_on_order_id ON spree_shipments USING btree (order_id);


--
-- Name: index_spree_shipments_on_stock_location_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_shipments_on_stock_location_id ON spree_shipments USING btree (stock_location_id);


--
-- Name: index_spree_shipping_method_categories_on_shipping_method_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_shipping_method_categories_on_shipping_method_id ON spree_shipping_method_categories USING btree (shipping_method_id);


--
-- Name: index_spree_shipping_methods_on_deleted_at_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_shipping_methods_on_deleted_at_id ON spree_shipping_methods USING btree (deleted_at, id);


--
-- Name: index_spree_shipping_methods_on_tax_category_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_shipping_methods_on_tax_category_id ON spree_shipping_methods USING btree (tax_category_id);


--
-- Name: index_spree_shipping_rates_on_selected; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_shipping_rates_on_selected ON spree_shipping_rates USING btree (selected);


--
-- Name: index_spree_shipping_rates_on_tax_rate_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_shipping_rates_on_tax_rate_id ON spree_shipping_rates USING btree (tax_rate_id);


--
-- Name: index_spree_state_changes_on_created_by_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_state_changes_on_created_by_id ON spree_state_changes USING btree (created_by_id);


--
-- Name: index_spree_state_changes_on_stateful_id_stateful_type; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_state_changes_on_stateful_id_stateful_type ON spree_state_changes USING btree (stateful_id, stateful_type);


--
-- Name: index_spree_state_changes_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_state_changes_on_user_id ON spree_state_changes USING btree (user_id);


--
-- Name: index_spree_stock_items_on_backorderable; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_stock_items_on_backorderable ON spree_stock_items USING btree (backorderable);


--
-- Name: index_spree_stock_items_on_deleted_at_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_stock_items_on_deleted_at_id ON spree_stock_items USING btree (deleted_at, id);


--
-- Name: index_spree_stock_items_on_stock_location_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_stock_items_on_stock_location_id ON spree_stock_items USING btree (stock_location_id);


--
-- Name: index_spree_stock_items_on_stock_location_id_variant_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_stock_items_on_stock_location_id_variant_id ON spree_stock_items USING btree (stock_location_id, variant_id);


--
-- Name: index_spree_stock_locations_on_active; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_stock_locations_on_active ON spree_stock_locations USING btree (active);


--
-- Name: index_spree_stock_locations_on_backorderable_default; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_stock_locations_on_backorderable_default ON spree_stock_locations USING btree (backorderable_default);


--
-- Name: index_spree_stock_locations_on_country_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_stock_locations_on_country_id ON spree_stock_locations USING btree (country_id);


--
-- Name: index_spree_stock_locations_on_id_default; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX index_spree_stock_locations_on_id_default ON spree_stock_locations USING btree (id) WHERE "default";


--
-- Name: index_spree_stock_locations_on_propagate_all_variants; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_stock_locations_on_propagate_all_variants ON spree_stock_locations USING btree (propagate_all_variants);


--
-- Name: index_spree_stock_locations_on_state_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_stock_locations_on_state_id ON spree_stock_locations USING btree (state_id);


--
-- Name: index_spree_stock_movements_on_stock_item_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_stock_movements_on_stock_item_id ON spree_stock_movements USING btree (stock_item_id);


--
-- Name: index_spree_stock_transfers_on_destination_location_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_stock_transfers_on_destination_location_id ON spree_stock_transfers USING btree (destination_location_id);


--
-- Name: index_spree_stock_transfers_on_source_location_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_stock_transfers_on_source_location_id ON spree_stock_transfers USING btree (source_location_id);


--
-- Name: index_spree_stores_on_code; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_stores_on_code ON spree_stores USING btree (code);


--
-- Name: index_spree_stores_on_default; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_stores_on_default ON spree_stores USING btree ("default");


--
-- Name: index_spree_stores_on_id_default; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX index_spree_stores_on_id_default ON spree_stores USING btree (id) WHERE "default";


--
-- Name: index_spree_stores_on_url; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_stores_on_url ON spree_stores USING btree (url);


--
-- Name: index_spree_tax_categories_on_deleted_at_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_tax_categories_on_deleted_at_id ON spree_tax_categories USING btree (deleted_at, id);


--
-- Name: index_spree_tax_categories_on_is_default; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_tax_categories_on_is_default ON spree_tax_categories USING btree (is_default);


--
-- Name: index_spree_tax_rates_on_deleted_at_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_tax_rates_on_deleted_at_id ON spree_tax_rates USING btree (deleted_at, id);


--
-- Name: index_spree_tax_rates_on_included_in_price; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_tax_rates_on_included_in_price ON spree_tax_rates USING btree (included_in_price);


--
-- Name: index_spree_tax_rates_on_show_rate_in_label; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_tax_rates_on_show_rate_in_label ON spree_tax_rates USING btree (show_rate_in_label);


--
-- Name: index_spree_tax_rates_on_tax_category_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_tax_rates_on_tax_category_id ON spree_tax_rates USING btree (tax_category_id);


--
-- Name: index_spree_tax_rates_on_zone_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_tax_rates_on_zone_id ON spree_tax_rates USING btree (zone_id);


--
-- Name: index_spree_taxonomies_on_position; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_taxonomies_on_position ON spree_taxonomies USING btree ("position");


--
-- Name: index_spree_taxons_on_parent_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_taxons_on_parent_id ON spree_taxons USING btree (parent_id);


--
-- Name: index_spree_taxons_on_permalink; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_taxons_on_permalink ON spree_taxons USING btree (permalink);


--
-- Name: index_spree_taxons_on_position; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_taxons_on_position ON spree_taxons USING btree ("position");


--
-- Name: index_spree_taxons_on_taxonomy_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_taxons_on_taxonomy_id ON spree_taxons USING btree (taxonomy_id);


--
-- Name: index_spree_taxons_promotion_rules_on_promotion_rule_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_taxons_promotion_rules_on_promotion_rule_id ON spree_taxons_promotion_rules USING btree (promotion_rule_id);


--
-- Name: index_spree_taxons_prototypes_on_prototype_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_taxons_prototypes_on_prototype_id ON spree_taxons_prototypes USING btree (prototype_id);


--
-- Name: index_spree_tokenized_permissions_on_permissable_id_permissable; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_tokenized_permissions_on_permissable_id_permissable ON spree_tokenized_permissions USING btree (permissable_id, permissable_type);


--
-- Name: index_spree_trackers_on_active; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_trackers_on_active ON spree_trackers USING btree (active);


--
-- Name: index_spree_users_on_bill_address_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_users_on_bill_address_id ON spree_users USING btree (bill_address_id);


--
-- Name: index_spree_users_on_deleted_at; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_users_on_deleted_at ON spree_users USING btree (deleted_at);


--
-- Name: index_spree_users_on_ship_address_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_users_on_ship_address_id ON spree_users USING btree (ship_address_id);


--
-- Name: index_spree_users_on_spree_api_key; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_users_on_spree_api_key ON spree_users USING btree (spree_api_key);


--
-- Name: index_spree_variants_on_deleted_at_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_variants_on_deleted_at_id ON spree_variants USING btree (deleted_at, id);


--
-- Name: index_spree_variants_on_is_master; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_variants_on_is_master ON spree_variants USING btree (is_master);


--
-- Name: index_spree_variants_on_position; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_variants_on_position ON spree_variants USING btree ("position");


--
-- Name: index_spree_variants_on_product_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_variants_on_product_id ON spree_variants USING btree (product_id);


--
-- Name: index_spree_variants_on_tax_category_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_variants_on_tax_category_id ON spree_variants USING btree (tax_category_id);


--
-- Name: index_spree_variants_on_track_inventory; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_variants_on_track_inventory ON spree_variants USING btree (track_inventory);


--
-- Name: index_spree_zone_members_on_zone_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_zone_members_on_zone_id ON spree_zone_members USING btree (zone_id);


--
-- Name: index_spree_zone_members_on_zoneable_id_zoneable_type; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_zone_members_on_zoneable_id_zoneable_type ON spree_zone_members USING btree (zoneable_id, zoneable_type);


--
-- Name: index_spree_zones_on_default_tax; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX index_spree_zones_on_default_tax ON spree_zones USING btree (default_tax);


--
-- Name: spree_orders_on_canceler_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX spree_orders_on_canceler_id ON spree_orders USING btree (canceler_id);


--
-- Name: spree_orders_on_store_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE INDEX spree_orders_on_store_id ON spree_orders USING btree (store_id);


--
-- Name: unique_friendly_id_slugs_on_sluggable_id_sluggable_type; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX unique_friendly_id_slugs_on_sluggable_id_sluggable_type ON friendly_id_slugs USING btree (sluggable_id, sluggable_type) WHERE (deleted_at IS NOT NULL);


--
-- Name: unique_incomplete_spree_orders; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX unique_incomplete_spree_orders ON spree_orders USING btree (user_id, currency) WHERE (completed_at IS NULL);


--
-- Name: unique_schema_migrations_on_version; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX unique_schema_migrations_on_version ON schema_migrations USING btree (version);


--
-- Name: unique_spree_customer_returns_on_number; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX unique_spree_customer_returns_on_number ON spree_customer_returns USING btree (number);


--
-- Name: unique_spree_line_items_on_variant_id_order_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX unique_spree_line_items_on_variant_id_order_id ON spree_line_items USING btree (variant_id, order_id);


--
-- Name: unique_spree_orders_on_number; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX unique_spree_orders_on_number ON spree_orders USING btree (number);


--
-- Name: unique_spree_preferences_on_key; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX unique_spree_preferences_on_key ON spree_preferences USING btree (key);


--
-- Name: unique_spree_products_on_name; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX unique_spree_products_on_name ON spree_products USING btree (name) WHERE (deleted_at IS NOT NULL);


--
-- Name: unique_spree_products_on_slug; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX unique_spree_products_on_slug ON spree_products USING btree (slug);


--
-- Name: unique_spree_promotion_categories_on_name; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX unique_spree_promotion_categories_on_name ON spree_promotion_categories USING btree (name);


--
-- Name: unique_spree_refund_reasons_on_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX unique_spree_refund_reasons_on_id ON spree_refund_reasons USING btree (id) WHERE "default";


--
-- Name: unique_spree_refund_reasons_on_name; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX unique_spree_refund_reasons_on_name ON spree_refund_reasons USING btree (name);


--
-- Name: unique_spree_reimbursement_types_on_name; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX unique_spree_reimbursement_types_on_name ON spree_reimbursement_types USING btree (name);


--
-- Name: unique_spree_reimbursement_types_on_type; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX unique_spree_reimbursement_types_on_type ON spree_reimbursement_types USING btree (type);


--
-- Name: unique_spree_reimbursements_on_number; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX unique_spree_reimbursements_on_number ON spree_reimbursements USING btree (number);


--
-- Name: unique_spree_reimbursements_on_order_id_customer_return_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX unique_spree_reimbursements_on_order_id_customer_return_id ON spree_reimbursements USING btree (order_id, customer_return_id);


--
-- Name: unique_spree_return_authorization_reasons_on_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX unique_spree_return_authorization_reasons_on_id ON spree_return_authorization_reasons USING btree (id) WHERE "default";


--
-- Name: unique_spree_return_authorization_reasons_on_name; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX unique_spree_return_authorization_reasons_on_name ON spree_return_authorization_reasons USING btree (name);


--
-- Name: unique_spree_shipments_on_number; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX unique_spree_shipments_on_number ON spree_shipments USING btree (number);


--
-- Name: unique_spree_shipping_method_categories_on_shipping_category_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX unique_spree_shipping_method_categories_on_shipping_category_id ON spree_shipping_method_categories USING btree (shipping_category_id, shipping_method_id);


--
-- Name: unique_spree_shipping_rates_on_shipment_id_shipping_method_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX unique_spree_shipping_rates_on_shipment_id_shipping_method_id ON spree_shipping_rates USING btree (shipment_id, shipping_method_id);


--
-- Name: unique_spree_states_on_country_id_and_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX unique_spree_states_on_country_id_and_id ON spree_states USING btree (country_id, id);


--
-- Name: unique_spree_stock_transfers_on_number; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX unique_spree_stock_transfers_on_number ON spree_stock_transfers USING btree (number);


--
-- Name: unique_spree_stores_on_name; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX unique_spree_stores_on_name ON spree_stores USING btree (name);


--
-- Name: unique_spree_taxons_promotion_rules_on_taxon_id_promotion_rule_; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX unique_spree_taxons_promotion_rules_on_taxon_id_promotion_rule_ ON spree_taxons_promotion_rules USING btree (taxon_id, promotion_rule_id);


--
-- Name: unique_spree_taxons_prototypes_on_taxon_id_prototype_id; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX unique_spree_taxons_prototypes_on_taxon_id_prototype_id ON spree_taxons_prototypes USING btree (taxon_id, prototype_id);


--
-- Name: unique_spree_users_on_email; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX unique_spree_users_on_email ON spree_users USING btree (email);


--
-- Name: unique_spree_variants_on_sku; Type: INDEX; Schema: public; Owner: -; Tablespace:
--

CREATE UNIQUE INDEX unique_spree_variants_on_sku ON spree_variants USING btree (sku) WHERE ((deleted_at IS NULL) AND (length((sku)::text) > 0));


--
-- Name: fk_spree_addresses_country_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_addresses
    ADD CONSTRAINT fk_spree_addresses_country_id FOREIGN KEY (country_id) REFERENCES spree_countries(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_addresses_country_id_and_state_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_addresses
    ADD CONSTRAINT fk_spree_addresses_country_id_and_state_id FOREIGN KEY (country_id, state_id) REFERENCES spree_states(country_id, id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_addresses_state_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_addresses
    ADD CONSTRAINT fk_spree_addresses_state_id FOREIGN KEY (state_id) REFERENCES spree_states(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_adjustments; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_adjustments
    ADD CONSTRAINT fk_spree_adjustments FOREIGN KEY (order_id) REFERENCES spree_orders(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_credit_cards_address_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_credit_cards
    ADD CONSTRAINT fk_spree_credit_cards_address_id FOREIGN KEY (address_id) REFERENCES spree_addresses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_credit_cards_payment_method_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_credit_cards
    ADD CONSTRAINT fk_spree_credit_cards_payment_method_id FOREIGN KEY (payment_method_id) REFERENCES spree_payment_methods(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_credit_cards_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_credit_cards
    ADD CONSTRAINT fk_spree_credit_cards_user_id FOREIGN KEY (user_id) REFERENCES spree_users(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_customer_returns_stock_location_id_spree_stock_locatio; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_customer_returns
    ADD CONSTRAINT fk_spree_customer_returns_stock_location_id_spree_stock_locatio FOREIGN KEY (stock_location_id) REFERENCES spree_stock_locations(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_inventory_units_line_item_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_inventory_units
    ADD CONSTRAINT fk_spree_inventory_units_line_item_id FOREIGN KEY (line_item_id) REFERENCES spree_line_items(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_inventory_units_order_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_inventory_units
    ADD CONSTRAINT fk_spree_inventory_units_order_id FOREIGN KEY (order_id) REFERENCES spree_orders(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_inventory_units_return_authorization_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_inventory_units
    ADD CONSTRAINT fk_spree_inventory_units_return_authorization_id FOREIGN KEY (return_authorization_id) REFERENCES spree_return_authorizations(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_inventory_units_shipment_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_inventory_units
    ADD CONSTRAINT fk_spree_inventory_units_shipment_id FOREIGN KEY (shipment_id) REFERENCES spree_shipments(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_inventory_units_variant_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_inventory_units
    ADD CONSTRAINT fk_spree_inventory_units_variant_id FOREIGN KEY (variant_id) REFERENCES spree_variants(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_line_items_order_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_line_items
    ADD CONSTRAINT fk_spree_line_items_order_id FOREIGN KEY (order_id) REFERENCES spree_orders(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_line_items_tax_category_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_line_items
    ADD CONSTRAINT fk_spree_line_items_tax_category_id FOREIGN KEY (tax_category_id) REFERENCES spree_tax_categories(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_line_items_variant_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_line_items
    ADD CONSTRAINT fk_spree_line_items_variant_id FOREIGN KEY (variant_id) REFERENCES spree_variants(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_option_types_prototypes_option_type_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_option_types_prototypes
    ADD CONSTRAINT fk_spree_option_types_prototypes_option_type_id FOREIGN KEY (option_type_id) REFERENCES spree_option_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_option_types_prototypes_prototype_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_option_types_prototypes
    ADD CONSTRAINT fk_spree_option_types_prototypes_prototype_id FOREIGN KEY (prototype_id) REFERENCES spree_prototypes(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_option_values_option_type_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_option_values
    ADD CONSTRAINT fk_spree_option_values_option_type_id FOREIGN KEY (option_type_id) REFERENCES spree_option_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_option_values_variants_option_value_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_option_values_variants
    ADD CONSTRAINT fk_spree_option_values_variants_option_value_id FOREIGN KEY (option_value_id) REFERENCES spree_option_values(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_option_values_variants_variant_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_option_values_variants
    ADD CONSTRAINT fk_spree_option_values_variants_variant_id FOREIGN KEY (variant_id) REFERENCES spree_variants(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_orders_approver_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_orders
    ADD CONSTRAINT fk_spree_orders_approver_id FOREIGN KEY (approver_id) REFERENCES spree_users(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_orders_bill_address_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_orders
    ADD CONSTRAINT fk_spree_orders_bill_address_id FOREIGN KEY (bill_address_id) REFERENCES spree_addresses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_orders_canceler_id_spree_users_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_orders
    ADD CONSTRAINT fk_spree_orders_canceler_id_spree_users_id FOREIGN KEY (canceler_id) REFERENCES spree_users(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_orders_created_by_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_orders
    ADD CONSTRAINT fk_spree_orders_created_by_id FOREIGN KEY (created_by_id) REFERENCES spree_users(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_orders_promotions_order_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_orders_promotions
    ADD CONSTRAINT fk_spree_orders_promotions_order_id FOREIGN KEY (order_id) REFERENCES spree_orders(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_orders_promotions_promotion_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_orders_promotions
    ADD CONSTRAINT fk_spree_orders_promotions_promotion_id FOREIGN KEY (promotion_id) REFERENCES spree_promotions(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_orders_ship_address_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_orders
    ADD CONSTRAINT fk_spree_orders_ship_address_id FOREIGN KEY (ship_address_id) REFERENCES spree_addresses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_orders_store_id_spree_stores_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_orders
    ADD CONSTRAINT fk_spree_orders_store_id_spree_stores_id FOREIGN KEY (store_id) REFERENCES spree_stores(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_orders_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_orders
    ADD CONSTRAINT fk_spree_orders_user_id FOREIGN KEY (user_id) REFERENCES spree_users(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_payment_capture_events_payment_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_payment_capture_events
    ADD CONSTRAINT fk_spree_payment_capture_events_payment_id FOREIGN KEY (payment_id) REFERENCES spree_payments(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_payments_order_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_payments
    ADD CONSTRAINT fk_spree_payments_order_id FOREIGN KEY (order_id) REFERENCES spree_orders(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_payments_payment_method_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_payments
    ADD CONSTRAINT fk_spree_payments_payment_method_id FOREIGN KEY (payment_method_id) REFERENCES spree_payment_methods(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_prices_variant_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_prices
    ADD CONSTRAINT fk_spree_prices_variant_id FOREIGN KEY (variant_id) REFERENCES spree_variants(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_product_option_types_option_type_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_product_option_types
    ADD CONSTRAINT fk_spree_product_option_types_option_type_id FOREIGN KEY (option_type_id) REFERENCES spree_option_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_product_option_types_product_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_product_option_types
    ADD CONSTRAINT fk_spree_product_option_types_product_id FOREIGN KEY (product_id) REFERENCES spree_products(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_product_packages_product_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_product_packages
    ADD CONSTRAINT fk_spree_product_packages_product_id FOREIGN KEY (product_id) REFERENCES spree_products(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_product_properties_product_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_product_properties
    ADD CONSTRAINT fk_spree_product_properties_product_id FOREIGN KEY (product_id) REFERENCES spree_products(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_product_properties_property_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_product_properties
    ADD CONSTRAINT fk_spree_product_properties_property_id FOREIGN KEY (property_id) REFERENCES spree_properties(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_products_promotion_rules_product_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_products_promotion_rules
    ADD CONSTRAINT fk_spree_products_promotion_rules_product_id FOREIGN KEY (product_id) REFERENCES spree_products(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_products_promotion_rules_promotion_rule_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_products_promotion_rules
    ADD CONSTRAINT fk_spree_products_promotion_rules_promotion_rule_id FOREIGN KEY (promotion_rule_id) REFERENCES spree_promotion_rules(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_products_shipping_category_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_products
    ADD CONSTRAINT fk_spree_products_shipping_category_id FOREIGN KEY (shipping_category_id) REFERENCES spree_shipping_categories(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_products_tax_category_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_products
    ADD CONSTRAINT fk_spree_products_tax_category_id FOREIGN KEY (tax_category_id) REFERENCES spree_tax_categories(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_products_taxons_product_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_products_taxons
    ADD CONSTRAINT fk_spree_products_taxons_product_id FOREIGN KEY (product_id) REFERENCES spree_products(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_products_taxons_taxon_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_products_taxons
    ADD CONSTRAINT fk_spree_products_taxons_taxon_id FOREIGN KEY (taxon_id) REFERENCES spree_taxons(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_promotion_action_line_items_promotion_action_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_promotion_action_line_items
    ADD CONSTRAINT fk_spree_promotion_action_line_items_promotion_action_id FOREIGN KEY (promotion_action_id) REFERENCES spree_promotion_actions(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_promotion_action_line_items_variant_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_promotion_action_line_items
    ADD CONSTRAINT fk_spree_promotion_action_line_items_variant_id FOREIGN KEY (variant_id) REFERENCES spree_variants(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_promotion_actions_promotion_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_promotion_actions
    ADD CONSTRAINT fk_spree_promotion_actions_promotion_id FOREIGN KEY (promotion_id) REFERENCES spree_promotions(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_promotion_rules_promotion_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_promotion_rules
    ADD CONSTRAINT fk_spree_promotion_rules_promotion_id FOREIGN KEY (promotion_id) REFERENCES spree_promotions(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_promotion_rules_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_promotion_rules
    ADD CONSTRAINT fk_spree_promotion_rules_user_id FOREIGN KEY (user_id) REFERENCES spree_users(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_promotion_rules_users_promotion_rule_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_promotion_rules_users
    ADD CONSTRAINT fk_spree_promotion_rules_users_promotion_rule_id FOREIGN KEY (promotion_rule_id) REFERENCES spree_promotion_rules(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_promotion_rules_users_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_promotion_rules_users
    ADD CONSTRAINT fk_spree_promotion_rules_users_user_id FOREIGN KEY (user_id) REFERENCES spree_users(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_promotions_spree_promotion_category_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_promotions
    ADD CONSTRAINT fk_spree_promotions_spree_promotion_category_id FOREIGN KEY (promotion_category_id) REFERENCES spree_promotion_categories(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_properties_prototypes_property_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_properties_prototypes
    ADD CONSTRAINT fk_spree_properties_prototypes_property_id FOREIGN KEY (property_id) REFERENCES spree_properties(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_properties_prototypes_prototype_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_properties_prototypes
    ADD CONSTRAINT fk_spree_properties_prototypes_prototype_id FOREIGN KEY (prototype_id) REFERENCES spree_prototypes(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_refunds_payment_id_spree_payments_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_refunds
    ADD CONSTRAINT fk_spree_refunds_payment_id_spree_payments_id FOREIGN KEY (payment_id) REFERENCES spree_payments(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_refunds_refund_reason_id_spree_refund_reasons_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_refunds
    ADD CONSTRAINT fk_spree_refunds_refund_reason_id_spree_refund_reasons_id FOREIGN KEY (refund_reason_id) REFERENCES spree_refund_reasons(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_refunds_reimbursement_id_spree_reimbursements_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_refunds
    ADD CONSTRAINT fk_spree_refunds_reimbursement_id_spree_reimbursements_id FOREIGN KEY (reimbursement_id) REFERENCES spree_reimbursements(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_reimbursement_credits_reimbursement_id_spree_reimburse; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_reimbursement_credits
    ADD CONSTRAINT fk_spree_reimbursement_credits_reimbursement_id_spree_reimburse FOREIGN KEY (reimbursement_id) REFERENCES spree_reimbursements(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_reimbursements_customer_return_id_spree_customer_retur; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_reimbursements
    ADD CONSTRAINT fk_spree_reimbursements_customer_return_id_spree_customer_retur FOREIGN KEY (customer_return_id) REFERENCES spree_customer_returns(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_reimbursements_order_id_spree_orders_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_reimbursements
    ADD CONSTRAINT fk_spree_reimbursements_order_id_spree_orders_id FOREIGN KEY (order_id) REFERENCES spree_orders(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_return_authorizations_order_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_return_authorizations
    ADD CONSTRAINT fk_spree_return_authorizations_order_id FOREIGN KEY (order_id) REFERENCES spree_orders(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_return_authorizations_spree_return_authorizations_reas; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_return_authorizations
    ADD CONSTRAINT fk_spree_return_authorizations_spree_return_authorizations_reas FOREIGN KEY (return_authorization_reason_id) REFERENCES spree_return_authorization_reasons(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_return_authorizations_stock_location_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_return_authorizations
    ADD CONSTRAINT fk_spree_return_authorizations_stock_location_id FOREIGN KEY (stock_location_id) REFERENCES spree_stock_locations(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_return_items_customer_return_id_spree_customer_returns; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_return_items
    ADD CONSTRAINT fk_spree_return_items_customer_return_id_spree_customer_returns FOREIGN KEY (customer_return_id) REFERENCES spree_customer_returns(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_return_items_exchange_inventory_unit_id_spree_inventor; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_return_items
    ADD CONSTRAINT fk_spree_return_items_exchange_inventory_unit_id_spree_inventor FOREIGN KEY (exchange_inventory_unit_id) REFERENCES spree_inventory_units(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_return_items_exchange_variant_id_spree_variants_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_return_items
    ADD CONSTRAINT fk_spree_return_items_exchange_variant_id_spree_variants_id FOREIGN KEY (exchange_variant_id) REFERENCES spree_variants(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_return_items_inventory_unit_id_spree_inventory_units_i; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_return_items
    ADD CONSTRAINT fk_spree_return_items_inventory_unit_id_spree_inventory_units_i FOREIGN KEY (inventory_unit_id) REFERENCES spree_inventory_units(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_return_items_override_reimbursement_type_id_spree_reim; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_return_items
    ADD CONSTRAINT fk_spree_return_items_override_reimbursement_type_id_spree_reim FOREIGN KEY (override_reimbursement_type_id) REFERENCES spree_reimbursement_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_return_items_preferred_reimbursement_type_id_spree_rei; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_return_items
    ADD CONSTRAINT fk_spree_return_items_preferred_reimbursement_type_id_spree_rei FOREIGN KEY (preferred_reimbursement_type_id) REFERENCES spree_reimbursement_types(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_return_items_reimbursement_id_spree_reimbursements_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_return_items
    ADD CONSTRAINT fk_spree_return_items_reimbursement_id_spree_reimbursements_id FOREIGN KEY (reimbursement_id) REFERENCES spree_reimbursements(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_return_items_return_authorization_id_spree_return_auth; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_return_items
    ADD CONSTRAINT fk_spree_return_items_return_authorization_id_spree_return_auth FOREIGN KEY (return_authorization_id) REFERENCES spree_return_authorizations(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_roles_users_role_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_roles_users
    ADD CONSTRAINT fk_spree_roles_users_role_id FOREIGN KEY (role_id) REFERENCES spree_roles(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_roles_users_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_roles_users
    ADD CONSTRAINT fk_spree_roles_users_user_id FOREIGN KEY (user_id) REFERENCES spree_users(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_shipments_address_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_shipments
    ADD CONSTRAINT fk_spree_shipments_address_id FOREIGN KEY (address_id) REFERENCES spree_addresses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_shipments_order_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_shipments
    ADD CONSTRAINT fk_spree_shipments_order_id FOREIGN KEY (order_id) REFERENCES spree_orders(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_shipments_stock_location_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_shipments
    ADD CONSTRAINT fk_spree_shipments_stock_location_id FOREIGN KEY (stock_location_id) REFERENCES spree_stock_locations(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_shipping_method_categories_shipping_category_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_shipping_method_categories
    ADD CONSTRAINT fk_spree_shipping_method_categories_shipping_category_id FOREIGN KEY (shipping_category_id) REFERENCES spree_shipping_categories(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_shipping_method_categories_shipping_method_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_shipping_method_categories
    ADD CONSTRAINT fk_spree_shipping_method_categories_shipping_method_id FOREIGN KEY (shipping_method_id) REFERENCES spree_shipping_methods(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_shipping_methods_tax_category_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_shipping_methods
    ADD CONSTRAINT fk_spree_shipping_methods_tax_category_id FOREIGN KEY (tax_category_id) REFERENCES spree_tax_categories(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_shipping_methods_zones_shipping_method_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_shipping_methods_zones
    ADD CONSTRAINT fk_spree_shipping_methods_zones_shipping_method_id FOREIGN KEY (shipping_method_id) REFERENCES spree_shipping_methods(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_shipping_methods_zones_zone_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_shipping_methods_zones
    ADD CONSTRAINT fk_spree_shipping_methods_zones_zone_id FOREIGN KEY (zone_id) REFERENCES spree_zones(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_shipping_rates_shipment_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_shipping_rates
    ADD CONSTRAINT fk_spree_shipping_rates_shipment_id FOREIGN KEY (shipment_id) REFERENCES spree_shipments(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_shipping_rates_shipping_method_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_shipping_rates
    ADD CONSTRAINT fk_spree_shipping_rates_shipping_method_id FOREIGN KEY (shipping_method_id) REFERENCES spree_shipping_methods(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_shipping_rates_tax_rate_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_shipping_rates
    ADD CONSTRAINT fk_spree_shipping_rates_tax_rate_id FOREIGN KEY (tax_rate_id) REFERENCES spree_tax_rates(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_state_changes_created_by_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_state_changes
    ADD CONSTRAINT fk_spree_state_changes_created_by_id FOREIGN KEY (created_by_id) REFERENCES spree_users(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_state_changes_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_state_changes
    ADD CONSTRAINT fk_spree_state_changes_user_id FOREIGN KEY (user_id) REFERENCES spree_users(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_states_country_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_states
    ADD CONSTRAINT fk_spree_states_country_id FOREIGN KEY (country_id) REFERENCES spree_countries(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_stock_items_stock_location_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_stock_items
    ADD CONSTRAINT fk_spree_stock_items_stock_location_id FOREIGN KEY (stock_location_id) REFERENCES spree_stock_locations(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_stock_items_variant_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_stock_items
    ADD CONSTRAINT fk_spree_stock_items_variant_id FOREIGN KEY (variant_id) REFERENCES spree_variants(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_stock_locations_country_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_stock_locations
    ADD CONSTRAINT fk_spree_stock_locations_country_id FOREIGN KEY (country_id) REFERENCES spree_countries(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_stock_locations_state_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_stock_locations
    ADD CONSTRAINT fk_spree_stock_locations_state_id FOREIGN KEY (state_id) REFERENCES spree_states(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_stock_movements_stock_item_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_stock_movements
    ADD CONSTRAINT fk_spree_stock_movements_stock_item_id FOREIGN KEY (stock_item_id) REFERENCES spree_stock_items(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_stock_transfers_destination_location_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_stock_transfers
    ADD CONSTRAINT fk_spree_stock_transfers_destination_location_id FOREIGN KEY (destination_location_id) REFERENCES spree_stock_locations(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_stock_transfers_source_location_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_stock_transfers
    ADD CONSTRAINT fk_spree_stock_transfers_source_location_id FOREIGN KEY (source_location_id) REFERENCES spree_stock_locations(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_tax_rates_tax_category_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_tax_rates
    ADD CONSTRAINT fk_spree_tax_rates_tax_category_id FOREIGN KEY (tax_category_id) REFERENCES spree_tax_categories(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_tax_rates_zone_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_tax_rates
    ADD CONSTRAINT fk_spree_tax_rates_zone_id FOREIGN KEY (zone_id) REFERENCES spree_zones(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_taxons_parent_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_taxons
    ADD CONSTRAINT fk_spree_taxons_parent_id FOREIGN KEY (parent_id) REFERENCES spree_taxons(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_taxons_promotion_rules_promotion_rule_id_spree_promoti; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_taxons_promotion_rules
    ADD CONSTRAINT fk_spree_taxons_promotion_rules_promotion_rule_id_spree_promoti FOREIGN KEY (promotion_rule_id) REFERENCES spree_promotion_rules(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_taxons_promotion_rules_taxon_id_spree_taxons_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_taxons_promotion_rules
    ADD CONSTRAINT fk_spree_taxons_promotion_rules_taxon_id_spree_taxons_id FOREIGN KEY (taxon_id) REFERENCES spree_taxons(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_taxons_prototypes_prototype_id_spree_prototypes_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_taxons_prototypes
    ADD CONSTRAINT fk_spree_taxons_prototypes_prototype_id_spree_prototypes_id FOREIGN KEY (prototype_id) REFERENCES spree_prototypes(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_taxons_prototypes_taxon_id_spree_taxons_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_taxons_prototypes
    ADD CONSTRAINT fk_spree_taxons_prototypes_taxon_id_spree_taxons_id FOREIGN KEY (taxon_id) REFERENCES spree_taxons(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_taxons_taxonomy_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_taxons
    ADD CONSTRAINT fk_spree_taxons_taxonomy_id FOREIGN KEY (taxonomy_id) REFERENCES spree_taxonomies(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_users_bill_address_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_users
    ADD CONSTRAINT fk_spree_users_bill_address_id FOREIGN KEY (bill_address_id) REFERENCES spree_addresses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_users_ship_address_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_users
    ADD CONSTRAINT fk_spree_users_ship_address_id FOREIGN KEY (ship_address_id) REFERENCES spree_addresses(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_variants_product_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_variants
    ADD CONSTRAINT fk_spree_variants_product_id FOREIGN KEY (product_id) REFERENCES spree_products(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_variants_tax_category_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_variants
    ADD CONSTRAINT fk_spree_variants_tax_category_id FOREIGN KEY (tax_category_id) REFERENCES spree_tax_categories(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: fk_spree_zone_members_zone_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY spree_zone_members
    ADD CONSTRAINT fk_spree_zone_members_zone_id FOREIGN KEY (zone_id) REFERENCES spree_zones(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user",public;
