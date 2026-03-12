-- Cerinta 10
-- Stergere secvente daca exista deja
DROP SEQUENCE client_seq;
DROP SEQUENCE produs_seq;
DROP SEQUENCE comanda_seq;
DROP SEQUENCE angajat_seq;
DROP SEQUENCE factura_seq;
DROP SEQUENCE recenzie_seq;
DROP SEQUENCE lista_seq;
DROP SEQUENCE categorie_seq;
DROP SEQUENCE furnizor_seq;

-- Creare secvențe
CREATE SEQUENCE client_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE produs_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE comanda_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE angajat_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE factura_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE recenzie_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE lista_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE categorie_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE furnizor_seq START WITH 1 INCREMENT BY 1;

-- Cerinta 11

-- CLIENT
CREATE TABLE CLIENT (
    client_id NUMBER(13) PRIMARY KEY,
    nume VARCHAR2(50) NOT NULL,
    prenume VARCHAR2(50) NOT NULL,
    email VARCHAR2(100) UNIQUE NOT NULL,
    telefon VARCHAR2(15),
    parola VARCHAR2(255) NOT NULL, --- logica criptarii se face in aplicatie la inserare/modificare
    data_inregistrare DATE DEFAULT SYSDATE NOT NULL
);

-- ADRESA_LIVRARE
CREATE TABLE ADRESA_LIVRARE (
    adresa_id NUMBER(13) PRIMARY KEY,
    client_id NUMBER(13) NOT NULL,
    strada VARCHAR2(100) NOT NULL,
    oras VARCHAR2(50) NOT NULL,
    judet VARCHAR2(50),
    tara VARCHAR2(50) NOT NULL,
    cod_postal VARCHAR2(10),
    este_implicita CHAR(1) DEFAULT 'N' CHECK (este_implicita IN ('Y', 'N')),
    CONSTRAINT fk_adresa_client FOREIGN KEY (client_id) REFERENCES CLIENT(client_id)
);

CREATE UNIQUE INDEX idx_adresa_implicita ON ADRESA_LIVRARE (
  CASE WHEN este_implicita = 'Y' THEN client_id ELSE NULL END
);



-- CATEGORIE
CREATE TABLE CATEGORIE (
    categorie_id NUMBER(13) PRIMARY KEY,
    nume VARCHAR2(50) NOT NULL UNIQUE,
    descriere VARCHAR2(200)
);

-- FURNIZOR
CREATE TABLE FURNIZOR (
    furnizor_id NUMBER(13) PRIMARY KEY,
    denumire VARCHAR2(100) NOT NULL,
    email VARCHAR2(100) UNIQUE NOT NULL,
    telefon VARCHAR2(15),
    data_contract DATE NOT NULL
);

CREATE OR REPLACE TRIGGER trg_furnizor_date_check
BEFORE INSERT OR UPDATE ON FURNIZOR
FOR EACH ROW
BEGIN
    IF :new.data_contract > SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20001, 'Contract date cannot be in the future');
    END IF;
END;
/

-- PRODUS
CREATE TABLE PRODUS (
    produs_id NUMBER(13) PRIMARY KEY,
    categorie_id NUMBER(13) NOT NULL,
    furnizor_id NUMBER(13) NOT NULL,
    denumire VARCHAR2(100) NOT NULL,
    descriere VARCHAR2(500),
    pret NUMBER(10,2) NOT NULL CHECK (pret > 0),
    stoc NUMBER(6) NOT NULL CHECK (stoc >= 0),
    discount NUMBER(3) CHECK (discount >= 0 AND discount <= 100),
    CONSTRAINT fk_produs_categorie FOREIGN KEY (categorie_id) REFERENCES CATEGORIE(categorie_id),
    CONSTRAINT fk_produs_furnizor FOREIGN KEY (furnizor_id) REFERENCES FURNIZOR(furnizor_id)
);

-- COMANDA
CREATE TABLE COMANDA (
    comanda_id NUMBER(13) PRIMARY KEY,
    client_id NUMBER(13) NOT NULL,
    adresa_id NUMBER(13) NOT NULL,
    data_comanda DATE DEFAULT SYSDATE NOT NULL,
    status VARCHAR2(20) DEFAULT 'in asteptare' CHECK (status IN ('in asteptare', 'livrata', 'anulata')),
    metoda_plata VARCHAR2(20) CHECK (metoda_plata IN ('card', 'numerar')),
    total NUMBER(10,2) CHECK (total > 0),
    CONSTRAINT fk_comanda_client FOREIGN KEY (client_id) REFERENCES CLIENT(client_id),
    CONSTRAINT fk_comanda_adresa FOREIGN KEY (adresa_id) REFERENCES ADRESA_LIVRARE(adresa_id)
);

CREATE OR REPLACE TRIGGER trg_check_data_comanda
BEFORE INSERT OR UPDATE ON COMANDA
FOR EACH ROW
BEGIN
  IF :NEW.data_comanda > SYSDATE THEN
    RAISE_APPLICATION_ERROR(-20002, 'Data comenzii nu poate fi in viitor.');
  END IF;
END;
/


-- DETALII_COMANDA (tabel asociativ M:N)
CREATE TABLE DETALII_COMANDA (
    comanda_id NUMBER(13) NOT NULL,
    produs_id NUMBER(13) NOT NULL,
    cantitate NUMBER(6) NOT NULL CHECK (cantitate >= 1),
    pret_unitar NUMBER(10,2) NOT NULL CHECK (pret_unitar > 0),
    valoare NUMBER(10,2) GENERATED ALWAYS AS (cantitate * pret_unitar) VIRTUAL, --- VIRTUAL -> nu ocupa spatiu fizic si calculeaza la citire
    PRIMARY KEY (comanda_id, produs_id),
    CONSTRAINT fk_detalii_comanda_comanda FOREIGN KEY (comanda_id) REFERENCES COMANDA(comanda_id),
    CONSTRAINT fk_detalii_comanda_produs FOREIGN KEY (produs_id) REFERENCES PRODUS(produs_id)
);

-- ANGAJAT
CREATE TABLE ANGAJAT (
    angajat_id NUMBER(13) PRIMARY KEY,
    nume VARCHAR2(50) NOT NULL,
    prenume VARCHAR2(50) NOT NULL,
    email VARCHAR2(100) UNIQUE NOT NULL,
    telefon VARCHAR2(15),
    data_angajare DATE DEFAULT SYSDATE NOT NULL,
    rol VARCHAR2(20) CHECK (rol IN ('operator', 'manager', 'expeditor'))
);

CREATE OR REPLACE TRIGGER trg_check_data_angajare
BEFORE INSERT OR UPDATE ON ANGAJAT
FOR EACH ROW
BEGIN
  IF :NEW.data_angajare > SYSDATE THEN
    RAISE_APPLICATION_ERROR(-20003, 'Data angajării nu poate fi în viitor.');
  END IF;
END;
/

-- PROCESARE_COMANDA (tabel asociativ M:N)
CREATE TABLE PROCESARE_COMANDA (
    comanda_id NUMBER(13) NOT NULL,
    angajat_id NUMBER(13) NOT NULL,
    data_proc DATE DEFAULT SYSDATE NOT NULL,
    observatii VARCHAR2(500) DEFAULT NULL,
    PRIMARY KEY (comanda_id, angajat_id),
    CONSTRAINT fk_proc_comanda_comanda FOREIGN KEY (comanda_id) REFERENCES COMANDA(comanda_id),
    CONSTRAINT fk_proc_comanda_angajat FOREIGN KEY (angajat_id) REFERENCES ANGAJAT(angajat_id)
);

CREATE OR REPLACE TRIGGER trg_check_data_proc
BEFORE INSERT OR UPDATE ON PROCESARE_COMANDA
FOR EACH ROW
BEGIN
  IF :NEW.data_proc > SYSDATE THEN
    RAISE_APPLICATION_ERROR(-20004, 'Data procesarii nu poate fi in viitor.');
  END IF;
END;
/


-- LIVRARE_COMANDA (tabel asociativ M:N)
CREATE TABLE LIVRARE_COMANDA (
    comanda_id NUMBER(13) NOT NULL,
    angajat_id NUMBER(13) NOT NULL,
    data_livrare DATE DEFAULT SYSDATE NOT NULL,
    PRIMARY KEY (comanda_id, angajat_id),
    CONSTRAINT fk_livr_comanda_comanda FOREIGN KEY (comanda_id) REFERENCES COMANDA(comanda_id),
    CONSTRAINT fk_livr_comanda_angajat FOREIGN KEY (angajat_id) REFERENCES ANGAJAT(angajat_id)
);

CREATE OR REPLACE TRIGGER trg_check_data_livrare
BEFORE INSERT OR UPDATE ON LIVRARE_COMANDA
FOR EACH ROW
BEGIN
  IF :NEW.data_livrare > SYSDATE THEN
    RAISE_APPLICATION_ERROR(-20005, 'Data livrarii nu poate fi in viitor.');
  END IF;
END;
/


-- RECENZIE_PRODUS
CREATE TABLE RECENZIE_PRODUS (
    recenzie_id NUMBER(13) PRIMARY KEY,
    produs_id NUMBER(13) NOT NULL,
    client_id NUMBER(13) NOT NULL,
    rating NUMBER(1) CHECK (rating BETWEEN 1 AND 5),
    comentariu VARCHAR2(500) NULL,
    data_recenzie DATE DEFAULT SYSDATE NOT NULL,
    CONSTRAINT fk_recenzie_produs FOREIGN KEY (produs_id) REFERENCES PRODUS(produs_id),
    CONSTRAINT fk_recenzie_client FOREIGN KEY (client_id) REFERENCES CLIENT(client_id)
);

CREATE OR REPLACE TRIGGER trg_check_data_recenzie
BEFORE INSERT OR UPDATE ON RECENZIE_PRODUS
FOR EACH ROW
BEGIN
  IF :NEW.data_recenzie > SYSDATE THEN
    RAISE_APPLICATION_ERROR(-20006, 'Data recenziei nu poate fi in viitor.');
  END IF;
END;
/

-- FACTURA
CREATE TABLE FACTURA (
    factura_id NUMBER(13) PRIMARY KEY,
    comanda_id NUMBER(13) UNIQUE NOT NULL,
    data_emitere DATE DEFAULT SYSDATE NOT NULL,
    total NUMBER(10,2) NOT NULL CHECK (total > 0),
    status_plata VARCHAR2(20) DEFAULT 'neplatita' CHECK (status_plata IN ('platita', 'neplatita')),
    CONSTRAINT fk_factura_comanda FOREIGN KEY (comanda_id) REFERENCES COMANDA(comanda_id)
);

CREATE OR REPLACE TRIGGER trg_check_data_emitere
BEFORE INSERT OR UPDATE ON FACTURA
FOR EACH ROW
BEGIN
  IF :NEW.data_emitere > SYSDATE THEN
    RAISE_APPLICATION_ERROR(-20007, 'Data emiterii facturii nu poate fi in viitor.');
  END IF;
END;
/


-- LISTA_DORINTE
CREATE TABLE LISTA_DORINTE (
    lista_id NUMBER(13) PRIMARY KEY,
    client_id NUMBER(13) NOT NULL,
    nume_lista VARCHAR2(100) NOT NULL,
    data_creare DATE DEFAULT SYSDATE NOT NULL,
    CONSTRAINT fk_lista_client FOREIGN KEY (client_id) REFERENCES CLIENT(client_id)
);

CREATE OR REPLACE TRIGGER trg_check_data_creare
BEFORE INSERT OR UPDATE ON LISTA_DORINTE
FOR EACH ROW
BEGIN
  IF :NEW.data_creare > SYSDATE THEN
    RAISE_APPLICATION_ERROR(-20008, 'Data crearii listei nu poate fi in viitor.');
  END IF;
END;
/


-- LISTA_DORINTE_PRODUS (tabel asociativ M:N)
CREATE TABLE LISTA_DORINTE_PRODUS (
    lista_id NUMBER(13) NOT NULL,
    produs_id NUMBER(13) NOT NULL,
    PRIMARY KEY (lista_id, produs_id),
    CONSTRAINT fk_lista_prod_lista FOREIGN KEY (lista_id) REFERENCES LISTA_DORINTE(lista_id),
    CONSTRAINT fk_lista_prod_produs FOREIGN KEY (produs_id) REFERENCES PRODUS(produs_id)
);


INSERT INTO CLIENT(client_id, nume, prenume, email, telefon, parola, data_inregistrare)
VALUES (client_seq.NEXTVAL, 'Popescu', 'Ion', 'ion.popescu@gmail.com', '0712345678', 'hash_parola1', SYSDATE);

INSERT INTO CLIENT(client_id, nume, prenume, email, telefon, parola, data_inregistrare)
VALUES (client_seq.NEXTVAL, 'Ionescu', 'Maria', 'maria.ionescu@gmail.com', '0722345678', 'hash_parola2', SYSDATE);

INSERT INTO CLIENT(client_id, nume, prenume, email, telefon, parola, data_inregistrare)
VALUES (client_seq.NEXTVAL, 'Georgescu', 'Alex', 'alex.georgescu@gmail.com', '0733345678', 'hash_parola3', SYSDATE);

INSERT INTO CLIENT(client_id, nume, prenume, email, telefon, parola, data_inregistrare)
VALUES (client_seq.NEXTVAL, 'Dumitrescu', 'Ana', 'ana.dumitrescu@gmail.com', '0744345678', 'hash_parola4', SYSDATE);

INSERT INTO CLIENT(client_id, nume, prenume, email, telefon, parola, data_inregistrare)
VALUES (client_seq.NEXTVAL, 'Marinescu', 'Dan', 'dan.marinescu@gmail.com', '0755345678', 'hash_parola5', SYSDATE);

COMMIT;

INSERT INTO ADRESA_LIVRARE(adresa_id, client_id, strada, oras, judet, tara, cod_postal, este_implicita)
VALUES (1, 1, 'Str. Florilor 5', 'Bucuresti', 'Ilfov', 'Romania', '010101', 'Y');

INSERT INTO ADRESA_LIVRARE(adresa_id, client_id, strada, oras, judet, tara, cod_postal, este_implicita)
VALUES (2, 1, 'Str. Lalelelor 10', 'Bucuresti', 'Ilfov', 'Romania', '010102', 'N');

INSERT INTO ADRESA_LIVRARE(adresa_id, client_id, strada, oras, judet, tara, cod_postal, este_implicita)
VALUES (3, 2, 'Str. Primaverii 20', 'Cluj-Napoca', 'Cluj', 'Romania', '400101', 'Y');

INSERT INTO ADRESA_LIVRARE(adresa_id, client_id, strada, oras, judet, tara, cod_postal, este_implicita)
VALUES (4, 3, 'Bd. Independentei 15', 'Iasi', 'Iasi', 'Romania', '700101', 'Y');

INSERT INTO ADRESA_LIVRARE(adresa_id, client_id, strada, oras, judet, tara, cod_postal, este_implicita)
VALUES (5, 4, 'Str. Unirii 1', 'Timisoara', 'Timis', 'Romania', '300101', 'Y');

COMMIT;

INSERT INTO CATEGORIE(categorie_id, nume, descriere)
VALUES (categorie_seq.NEXTVAL, 'Electrocasnice', 'Produse electrocasnice diverse');

INSERT INTO CATEGORIE(categorie_id, nume, descriere)
VALUES (categorie_seq.NEXTVAL, 'Electronice', 'Dispozitive electronice si accesorii');

INSERT INTO CATEGORIE(categorie_id, nume, descriere)
VALUES (categorie_seq.NEXTVAL, 'Imbracaminte', 'Articole de imbracaminte pentru toate varstele');

INSERT INTO CATEGORIE(categorie_id, nume, descriere)
VALUES (categorie_seq.NEXTVAL, 'Carti', 'Diverse carti si publicatii');

INSERT INTO CATEGORIE(categorie_id, nume, descriere)
VALUES (categorie_seq.NEXTVAL, 'Articole pentru casa', 'Produse pentru uz casnic');

COMMIT;

INSERT INTO FURNIZOR(furnizor_id, denumire, email, telefon, data_contract)
VALUES (furnizor_seq.NEXTVAL, 'Altex', 'contact@altex.ro', '0214567890', TO_DATE('2024-01-01', 'YYYY-MM-DD'));

INSERT INTO FURNIZOR(furnizor_id, denumire, email, telefon, data_contract)
VALUES (furnizor_seq.NEXTVAL, 'Flanco', 'contact@flanco.ro', '0219876543', TO_DATE('2023-06-15', 'YYYY-MM-DD'));

INSERT INTO FURNIZOR(furnizor_id, denumire, email, telefon, data_contract)
VALUES (furnizor_seq.NEXTVAL, 'Emag', 'contact@emag.ro', '0312345678', TO_DATE('2023-11-10', 'YYYY-MM-DD'));

INSERT INTO FURNIZOR(furnizor_id, denumire, email, telefon, data_contract)
VALUES (furnizor_seq.NEXTVAL, 'Carturesti', 'contact@carturesti.ro', '0318765432', TO_DATE('2024-02-20', 'YYYY-MM-DD'));

INSERT INTO FURNIZOR(furnizor_id, denumire, email, telefon, data_contract)
VALUES (furnizor_seq.NEXTVAL, 'Dedeman', 'contact@dedeman.ro', '0256347890', TO_DATE('2023-08-05', 'YYYY-MM-DD'));

COMMIT;

INSERT INTO PRODUS(produs_id, categorie_id, furnizor_id, denumire, descriere, pret, stoc, discount)
VALUES (produs_seq.NEXTVAL, 1, 1, 'Frigider Samsung', 'Frigider cu tehnologie no frost', 2300.00, 15, 10);

INSERT INTO PRODUS(produs_id, categorie_id, furnizor_id, denumire, descriere, pret, stoc, discount)
VALUES (produs_seq.NEXTVAL, 2, 2, 'Smartphone Samsung S24', 'Telefon performant cu ecran AMOLED', 4000.00, 30, NULL);

INSERT INTO PRODUS(produs_id, categorie_id, furnizor_id, denumire, descriere, pret, stoc, discount)
VALUES (produs_seq.NEXTVAL, 3, 3, 'Geaca de iarna', 'Geaca rezistenta si calduroasa', 350.00, 50, 5);

INSERT INTO PRODUS(produs_id, categorie_id, furnizor_id, denumire, descriere, pret, stoc, discount)
VALUES (produs_seq.NEXTVAL, 4, 4, 'Carte de istorie', 'Carte despre istoria Romaniei', 50.00, 100, NULL);

INSERT INTO PRODUS(produs_id, categorie_id, furnizor_id, denumire, descriere, pret, stoc, discount)
VALUES (produs_seq.NEXTVAL, 5, 5, 'Set tacamuri', 'Set de tacamuri inox pentru 12 persoane', 200.00, 20, 15);

COMMIT;

INSERT INTO COMANDA(comanda_id, client_id, adresa_id, data_comanda, status, metoda_plata, total)
VALUES (comanda_seq.NEXTVAL, 1, 1, TO_DATE('2025-03-15', 'YYYY-MM-DD'), 'in asteptare', 'card', 3000.00);

INSERT INTO COMANDA(comanda_id, client_id, adresa_id, data_comanda, status, metoda_plata, total)
VALUES (comanda_seq.NEXTVAL, 2, 3, TO_DATE('2025-03-14', 'YYYY-MM-DD'), 'livrata', 'numerar', 4200.00);

INSERT INTO COMANDA(comanda_id, client_id, adresa_id, data_comanda, status, metoda_plata, total)
VALUES (comanda_seq.NEXTVAL, 3, 4, TO_DATE('2025-03-13', 'YYYY-MM-DD'), 'anulata', 'card', 150.00);

INSERT INTO COMANDA(comanda_id, client_id, adresa_id, data_comanda, status, metoda_plata, total)
VALUES (comanda_seq.NEXTVAL, 4, 5, TO_DATE('2025-03-12', 'YYYY-MM-DD'), 'in asteptare', 'card', 2700.00);

INSERT INTO COMANDA(comanda_id, client_id, adresa_id, data_comanda, status, metoda_plata, total)
VALUES (comanda_seq.NEXTVAL, 5, 2, TO_DATE('2025-03-11', 'YYYY-MM-DD'), 'livrata', 'numerar', 4500.00);

COMMIT;

INSERT INTO ANGAJAT(angajat_id, nume, prenume, email, telefon, data_angajare, rol)
VALUES (angajat_seq.NEXTVAL, 'Ionescu', 'Maria', 'maria.ionescu@firma.ro', '0744000000', TO_DATE('2023-06-01', 'YYYY-MM-DD'), 'operator');

INSERT INTO ANGAJAT(angajat_id, nume, prenume, email, telefon, data_angajare, rol)
VALUES (angajat_seq.NEXTVAL, 'Popescu', 'Adrian', 'adrian.popescu@firma.ro', '0744111111', TO_DATE('2022-05-15', 'YYYY-MM-DD'), 'manager');

INSERT INTO ANGAJAT(angajat_id, nume, prenume, email, telefon, data_angajare, rol)
VALUES (angajat_seq.NEXTVAL, 'Georgescu', 'Ana', 'ana.georgescu@firma.ro', '0744222222', TO_DATE('2024-01-10', 'YYYY-MM-DD'), 'expeditor');

INSERT INTO ANGAJAT(angajat_id, nume, prenume, email, telefon, data_angajare, rol)
VALUES (angajat_seq.NEXTVAL, 'Dumitrescu', 'Ion', 'ion.dumitrescu@firma.ro', '0744333333', TO_DATE('2023-09-23', 'YYYY-MM-DD'), 'operator');

INSERT INTO ANGAJAT(angajat_id, nume, prenume, email, telefon, data_angajare, rol)
VALUES (angajat_seq.NEXTVAL, 'Marinescu', 'Elena', 'elena.marinescu@firma.ro', '0744444444', TO_DATE('2023-11-30', 'YYYY-MM-DD'), 'expeditor');

COMMIT;

INSERT INTO DETALII_COMANDA(comanda_id, produs_id, cantitate, pret_unitar) VALUES (3, 1, 1, 2300.00);
INSERT INTO DETALII_COMANDA(comanda_id, produs_id, cantitate, pret_unitar) VALUES (3, 3, 2, 350.00);
INSERT INTO DETALII_COMANDA(comanda_id, produs_id, cantitate, pret_unitar) VALUES (4, 2, 1, 4000.00);
INSERT INTO DETALII_COMANDA(comanda_id, produs_id, cantitate, pret_unitar) VALUES (4, 5, 1, 200.00);
INSERT INTO DETALII_COMANDA(comanda_id, produs_id, cantitate, pret_unitar) VALUES (5, 4, 3, 50.00);
INSERT INTO DETALII_COMANDA(comanda_id, produs_id, cantitate, pret_unitar) VALUES (6, 1, 1, 2300.00);
INSERT INTO DETALII_COMANDA(comanda_id, produs_id, cantitate, pret_unitar) VALUES (6, 5, 2, 200.00);
INSERT INTO DETALII_COMANDA(comanda_id, produs_id, cantitate, pret_unitar) VALUES (7, 3, 1, 350.00);
INSERT INTO DETALII_COMANDA(comanda_id, produs_id, cantitate, pret_unitar) VALUES (7, 4, 1, 50.00);
INSERT INTO DETALII_COMANDA(comanda_id, produs_id, cantitate, pret_unitar) VALUES (7, 2, 2, 4000.00);

COMMIT;


INSERT INTO PROCESARE_COMANDA(comanda_id, angajat_id, data_proc, observatii)
VALUES (3, 1, TO_DATE('2025-03-16', 'YYYY-MM-DD'), 'Validare comanda');

INSERT INTO PROCESARE_COMANDA(comanda_id, angajat_id, data_proc, observatii)
VALUES (3, 4, TO_DATE('2025-03-17', 'YYYY-MM-DD'), 'Ambalare produs');

INSERT INTO PROCESARE_COMANDA(comanda_id, angajat_id, data_proc, observatii)
VALUES (4, 2, TO_DATE('2025-03-14', 'YYYY-MM-DD'), 'Validare comanda');

INSERT INTO PROCESARE_COMANDA(comanda_id, angajat_id, data_proc, observatii)
VALUES (4, 5, TO_DATE('2025-03-15', 'YYYY-MM-DD'), 'Ambalare produs');

INSERT INTO PROCESARE_COMANDA(comanda_id, angajat_id, data_proc, observatii)
VALUES (5, 1, TO_DATE('2025-03-13', 'YYYY-MM-DD'), 'Validare comanda');

INSERT INTO PROCESARE_COMANDA(comanda_id, angajat_id, data_proc, observatii)
VALUES (6, 2, TO_DATE('2025-03-12', 'YYYY-MM-DD'), 'Validare comanda');

INSERT INTO PROCESARE_COMANDA(comanda_id, angajat_id, data_proc, observatii)
VALUES (6, 3, TO_DATE('2025-03-12', 'YYYY-MM-DD'), 'Ambalare produs');

INSERT INTO PROCESARE_COMANDA(comanda_id, angajat_id, data_proc, observatii)
VALUES (7, 1, TO_DATE('2025-03-11', 'YYYY-MM-DD'), 'Validare comanda');

INSERT INTO PROCESARE_COMANDA(comanda_id, angajat_id, data_proc, observatii)
VALUES (7, 4, TO_DATE('2025-03-11', 'YYYY-MM-DD'), 'Ambalare produs');

INSERT INTO PROCESARE_COMANDA(comanda_id, angajat_id, data_proc, observatii)
VALUES (7, 5, TO_DATE('2025-03-11', 'YYYY-MM-DD'), 'Livrare produs');

COMMIT;

INSERT INTO LIVRARE_COMANDA(comanda_id, angajat_id, data_livrare)
VALUES (3, 3, TO_DATE('2025-03-18', 'YYYY-MM-DD'));

INSERT INTO LIVRARE_COMANDA(comanda_id, angajat_id, data_livrare)
VALUES (3, 5, TO_DATE('2025-03-19', 'YYYY-MM-DD'));

INSERT INTO LIVRARE_COMANDA(comanda_id, angajat_id, data_livrare)
VALUES (4, 4, TO_DATE('2025-03-15', 'YYYY-MM-DD'));

INSERT INTO LIVRARE_COMANDA(comanda_id, angajat_id, data_livrare)
VALUES (4, 3, TO_DATE('2025-03-16', 'YYYY-MM-DD'));

INSERT INTO LIVRARE_COMANDA(comanda_id, angajat_id, data_livrare)
VALUES (5, 5, TO_DATE('2025-03-14', 'YYYY-MM-DD'));

INSERT INTO LIVRARE_COMANDA(comanda_id, angajat_id, data_livrare)
VALUES (6, 4, TO_DATE('2025-03-13', 'YYYY-MM-DD'));

INSERT INTO LIVRARE_COMANDA(comanda_id, angajat_id, data_livrare)
VALUES (6, 3, TO_DATE('2025-03-13', 'YYYY-MM-DD'));

INSERT INTO LIVRARE_COMANDA(comanda_id, angajat_id, data_livrare)
VALUES (7, 5, TO_DATE('2025-03-12', 'YYYY-MM-DD'));

INSERT INTO LIVRARE_COMANDA(comanda_id, angajat_id, data_livrare)
VALUES (7, 4, TO_DATE('2025-03-12', 'YYYY-MM-DD'));

INSERT INTO LIVRARE_COMANDA(comanda_id, angajat_id, data_livrare)
VALUES (7, 3, TO_DATE('2025-03-12', 'YYYY-MM-DD'));

COMMIT;


INSERT INTO RECENZIE_PRODUS(recenzie_id, produs_id, client_id, rating, comentariu, data_recenzie)
VALUES (recenzie_seq.NEXTVAL, 1, 1, 5, 'Foarte bun produs', TO_DATE('2025-03-20', 'YYYY-MM-DD'));

INSERT INTO RECENZIE_PRODUS(recenzie_id, produs_id, client_id, rating, comentariu, data_recenzie)
VALUES (recenzie_seq.NEXTVAL, 2, 2, 4, 'Bun raport calitate-pret', TO_DATE('2025-03-21', 'YYYY-MM-DD'));

INSERT INTO RECENZIE_PRODUS(recenzie_id, produs_id, client_id, rating, comentariu, data_recenzie)
VALUES (recenzie_seq.NEXTVAL, 3, 3, 3, 'Ok pentru pretul platit', TO_DATE('2025-03-22', 'YYYY-MM-DD'));

INSERT INTO RECENZIE_PRODUS(recenzie_id, produs_id, client_id, rating, comentariu, data_recenzie)
VALUES (recenzie_seq.NEXTVAL, 4, 4, 5, 'Excelent!', TO_DATE('2025-03-23', 'YYYY-MM-DD'));

INSERT INTO RECENZIE_PRODUS(recenzie_id, produs_id, client_id, rating, comentariu, data_recenzie)
VALUES (recenzie_seq.NEXTVAL, 5, 5, 4, NULL, TO_DATE('2025-03-24', 'YYYY-MM-DD'));

INSERT INTO RECENZIE_PRODUS(recenzie_id, produs_id, client_id, rating, comentariu, data_recenzie)
VALUES (recenzie_seq.NEXTVAL, 1, 2, 4, 'Recomand cu incredere', TO_DATE('2025-03-25', 'YYYY-MM-DD'));

INSERT INTO RECENZIE_PRODUS(recenzie_id, produs_id, client_id, rating, comentariu, data_recenzie)
VALUES (recenzie_seq.NEXTVAL, 3, 4, 2, 'Nu este ce ma asteptam', TO_DATE('2025-03-26', 'YYYY-MM-DD'));

INSERT INTO RECENZIE_PRODUS(recenzie_id, produs_id, client_id, rating, comentariu, data_recenzie)
VALUES (recenzie_seq.NEXTVAL, 2, 5, 5, 'Calitate superioara', TO_DATE('2025-03-27', 'YYYY-MM-DD'));

INSERT INTO RECENZIE_PRODUS(recenzie_id, produs_id, client_id, rating, comentariu, data_recenzie)
VALUES (recenzie_seq.NEXTVAL, 4, 1, 3, 'Acceptabil', TO_DATE('2025-03-28', 'YYYY-MM-DD'));

INSERT INTO RECENZIE_PRODUS(recenzie_id, produs_id, client_id, rating, comentariu, data_recenzie)
VALUES (recenzie_seq.NEXTVAL, 5, 3, 4, 'Multumit', TO_DATE('2025-03-29', 'YYYY-MM-DD'));

COMMIT;

INSERT INTO FACTURA(factura_id, comanda_id, data_emitere, total, status_plata)
VALUES (factura_seq.NEXTVAL, 3, TO_DATE('2025-03-20', 'YYYY-MM-DD'), 3000.00, 'neplatita');

INSERT INTO FACTURA(factura_id, comanda_id, data_emitere, total, status_plata)
VALUES (factura_seq.NEXTVAL, 4, TO_DATE('2025-03-19', 'YYYY-MM-DD'), 4200.00, 'platita');

INSERT INTO FACTURA(factura_id, comanda_id, data_emitere, total, status_plata)
VALUES (factura_seq.NEXTVAL, 5, TO_DATE('2025-03-18', 'YYYY-MM-DD'), 150.00, 'neplatita');

INSERT INTO FACTURA(factura_id, comanda_id, data_emitere, total, status_plata)
VALUES (factura_seq.NEXTVAL, 6, TO_DATE('2025-03-17', 'YYYY-MM-DD'), 2700.00, 'platita');

INSERT INTO FACTURA(factura_id, comanda_id, data_emitere, total, status_plata)
VALUES (factura_seq.NEXTVAL, 7, TO_DATE('2025-03-16', 'YYYY-MM-DD'), 4500.00, 'neplatita');

COMMIT;

INSERT INTO LISTA_DORINTE(lista_id, client_id, nume_lista, data_creare)
VALUES (lista_seq.NEXTVAL, 1, 'Wishlist Craciun', TO_DATE('2025-02-01', 'YYYY-MM-DD'));

INSERT INTO LISTA_DORINTE(lista_id, client_id, nume_lista, data_creare)
VALUES (lista_seq.NEXTVAL, 2, 'Wishlist Vara', TO_DATE('2025-03-01', 'YYYY-MM-DD'));

INSERT INTO LISTA_DORINTE(lista_id, client_id, nume_lista, data_creare)
VALUES (lista_seq.NEXTVAL, 3, 'Wishlist Paste', TO_DATE('2025-04-01', 'YYYY-MM-DD'));

INSERT INTO LISTA_DORINTE(lista_id, client_id, nume_lista, data_creare)
VALUES (lista_seq.NEXTVAL, 4, 'Wishlist Cadouri', TO_DATE('2025-05-01', 'YYYY-MM-DD'));

INSERT INTO LISTA_DORINTE(lista_id, client_id, nume_lista, data_creare)
VALUES (lista_seq.NEXTVAL, 5, 'Wishlist Aniversare', TO_DATE('2025-05-10', 'YYYY-MM-DD'));

COMMIT;


INSERT INTO LISTA_DORINTE_PRODUS(lista_id, produs_id) VALUES (1, 1);
INSERT INTO LISTA_DORINTE_PRODUS(lista_id, produs_id) VALUES (1, 2);
INSERT INTO LISTA_DORINTE_PRODUS(lista_id, produs_id) VALUES (1, 3);
INSERT INTO LISTA_DORINTE_PRODUS(lista_id, produs_id) VALUES (2, 3);
INSERT INTO LISTA_DORINTE_PRODUS(lista_id, produs_id) VALUES (2, 4);
INSERT INTO LISTA_DORINTE_PRODUS(lista_id, produs_id) VALUES (2, 5);
INSERT INTO LISTA_DORINTE_PRODUS(lista_id, produs_id) VALUES (3, 1);
INSERT INTO LISTA_DORINTE_PRODUS(lista_id, produs_id) VALUES (3, 4);
INSERT INTO LISTA_DORINTE_PRODUS(lista_id, produs_id) VALUES (3, 5);
INSERT INTO LISTA_DORINTE_PRODUS(lista_id, produs_id) VALUES (4, 2);
INSERT INTO LISTA_DORINTE_PRODUS(lista_id, produs_id) VALUES (4, 3);
INSERT INTO LISTA_DORINTE_PRODUS(lista_id, produs_id) VALUES (4, 5);
INSERT INTO LISTA_DORINTE_PRODUS(lista_id, produs_id) VALUES (5, 1);
INSERT INTO LISTA_DORINTE_PRODUS(lista_id, produs_id) VALUES (5, 4);
INSERT INTO LISTA_DORINTE_PRODUS(lista_id, produs_id) VALUES (5, 5);

COMMIT;

--- Cerinta 12

--- Cererea 1
--- Sa se afiseze comenzile (ID, numele complet al clientului, data si totalul) care au fost procesate de cel putin doi angajati
--- diferiti si contin cel putin doua produse diferite in detalii.
--- subpunctul a) - subcereri sincronizate cu cel putin 3 tabele

SELECT c.comanda_id,
       cl.nume || ' ' || cl.prenume AS client_nume,
       c.data_comanda,
       c.total
FROM COMANDA c
JOIN CLIENT cl ON c.client_id = cl.client_id
WHERE (
    SELECT COUNT(DISTINCT pc.angajat_id)
    FROM PROCESARE_COMANDA pc
    WHERE pc.comanda_id = c.comanda_id
) >= 2
AND (
    SELECT COUNT(*)
    FROM DETALII_COMANDA dc
    WHERE dc.comanda_id = c.comanda_id
) >= 2
ORDER BY c.data_comanda DESC;



--- Cererea 2
--- Se se afiseze toate comenzile, impreuna cu numarul de produse distincte si suma totala a cantitatilor, inclusiv comenzile fara detalii.
--- subpunctul b) - subcereri nesincronizate in clauza FROM

SELECT c.comanda_id, cl.nume || ' ' || cl.prenume AS client,
       NVL(prod.nr_produse, 0) AS nr_produse,
       NVL(prod.total_cantitate, 0) AS total_cantitate
FROM COMANDA c
JOIN CLIENT cl ON c.client_id = cl.client_id
LEFT JOIN (
    SELECT comanda_id, COUNT(DISTINCT produs_id) AS nr_produse,
           SUM(cantitate) AS total_cantitate
    FROM DETALII_COMANDA
    GROUP BY comanda_id
) prod ON c.comanda_id = prod.comanda_id
ORDER BY c.comanda_id;



--- Cererea 3
--- Sa se afiseze, pentru fiecare categorie, numarul total de produse si media reducerii aplicate produselor din acea categorie.
--- Se vor afisa doar acele categorii care au mai multe produse cu discount decat numarul total de produse fara discount din intreg magazinul.
--- subpunctele c), d) - grupari de date, functii grup, HAVING cu subcerere nesincronizata + ordonari, NVL, DECODE

SELECT cat.nume AS categorie,
       COUNT(p.produs_id) AS total_produse,
       NVL(ROUND(AVG(p.discount), 2), 0) AS media_discount,
       DECODE(MAX(p.discount), NULL, 'Fara reducere', 'Are reduceri') AS tip_reducere
FROM CATEGORIE cat
LEFT JOIN PRODUS p ON cat.categorie_id = p.categorie_id
GROUP BY cat.categorie_id, cat.nume
HAVING COUNT(p.discount) > (
    SELECT COUNT(*)
    FROM PRODUS
    WHERE discount IS NULL
)
ORDER BY media_discount DESC;



--- Cererea 4
--- Sa se afiseze recenziile detaliate (client, produs, data, comentariu) doar pentru recenziile mai recente de 60 de zile.
--- subpunctul e) - functii pe siruri (UPPER, SUBSTR), functii calendaristice (SYSDATE, TRUNC), CASE

SELECT cl.nume || ' ' || cl.prenume AS client,
       UPPER(SUBSTR(p.denumire, 1, 20)) AS produs,
       r.data_recenzie,
       CASE
           WHEN r.rating >= 4 THEN 'Pozitiva'
           WHEN r.rating = 3 THEN 'Neutra'
           ELSE 'Negativa'
       END AS evaluare,
       r.comentariu
FROM RECENZIE_PRODUS r
JOIN CLIENT cl ON r.client_id = cl.client_id
JOIN PRODUS p ON r.produs_id = p.produs_id
WHERE r.data_recenzie >= TRUNC(SYSDATE - 60)
ORDER BY r.data_recenzie DESC;


--- Cererea 5
--- Pentru fiecare furnizor, sa se afiseze numarul de produse, data celui mai recent contract si numarul de comenzi in care apar produsele sale.
--- subpunctul f) - bloc WITH

WITH ProduseFurnizori AS (
  SELECT f.furnizor_id, f.denumire, MAX(f.data_contract) AS data_contract,
         COUNT(DISTINCT p.produs_id) AS nr_produse
  FROM FURNIZOR f
  JOIN PRODUS p ON f.furnizor_id = p.furnizor_id
  GROUP BY f.furnizor_id, f.denumire
),
ComenziFurnizori AS (
  SELECT p.furnizor_id, COUNT(DISTINCT dc.comanda_id) AS nr_comenzi
  FROM PRODUS p
  JOIN DETALII_COMANDA dc ON p.produs_id = dc.produs_id
  GROUP BY p.furnizor_id
)
SELECT pf.denumire, pf.nr_produse, pf.data_contract,
       NVL(cf.nr_comenzi, 0) AS nr_comenzi
FROM ProduseFurnizori pf
LEFT JOIN ComenziFurnizori cf ON pf.furnizor_id = cf.furnizor_id
ORDER BY nr_comenzi DESC;


--- Cerinta 13

--- 1) Sa se actualizeze discount-ul fiecarui produs la 10% daca apartine unei categorii care are in medie mai putin de 3 produse.
--- UPDATE cu subcerere in SET

UPDATE PRODUS
SET discount = 10
WHERE categorie_id IN (
  SELECT categorie_id
  FROM (
    SELECT categorie_id, COUNT(*) AS nr_produse
    FROM PRODUS
    GROUP BY categorie_id
  )
  WHERE nr_produse < 3
);

SELECT p.produs_id, p.denumire, p.discount, c.nume AS categorie
FROM PRODUS p
JOIN CATEGORIE c ON p.categorie_id = c.categorie_id
ORDER BY c.nume;

--- 2) Sa se seteze status_plata = 'platita' pentru toate facturile ale caror comenzi au fost livrate de angajata Elena Marinescu.
--- UPDATE cu subcerere in WHERE si SET

UPDATE FACTURA
SET status_plata = 'platita'
WHERE comanda_id IN (
  SELECT comanda_id
  FROM LIVRARE_COMANDA
  WHERE angajat_id = (
    SELECT angajat_id
    FROM ANGAJAT
    WHERE nume = 'Marinescu' AND prenume = 'Elena'
  )
);

SELECT f.factura_id, f.comanda_id, f.status_plata
FROM FACTURA f
ORDER BY f.factura_id;


--- 3)
--- Sa se stearga toate recenziile lasate de clientii care nu au facut nicio comanda.
--- DELETE cu subcerere

DELETE FROM RECENZIE_PRODUS
WHERE client_id IN (
  SELECT client_id
  FROM CLIENT
  WHERE client_id NOT IN (
    SELECT DISTINCT client_id
    FROM COMANDA
  )
);

SELECT r.recenzie_id, r.client_id, c.nume || ' ' || c.prenume AS client
FROM RECENZIE_PRODUS r
JOIN CLIENT c ON r.client_id = c.client_id
ORDER BY r.client_id;


--- Cerinta 14

CREATE VIEW v_comenzi_detalii AS
SELECT
    c.comanda_id,
    cl.nume || ' ' || cl.prenume AS client,
    c.data_comanda,
    c.status AS status_comanda,
    c.total AS total_comanda,
    p.denumire AS produs,
    dc.cantitate,
    dc.pret_unitar,
    dc.valoare,
    e1.nume || ' ' || e1.prenume AS operator,
    e2.nume || ' ' || e2.prenume AS expeditor,
    lc.data_livrare
FROM
    COMANDA c
JOIN CLIENT cl ON c.client_id = cl.client_id
JOIN DETALII_COMANDA dc ON c.comanda_id = dc.comanda_id
JOIN PRODUS p ON dc.produs_id = p.produs_id
LEFT JOIN PROCESARE_COMANDA pc ON c.comanda_id = pc.comanda_id
LEFT JOIN ANGAJAT e1 ON pc.angajat_id = e1.angajat_id AND e1.rol = 'operator'
LEFT JOIN LIVRARE_COMANDA lc ON c.comanda_id = lc.comanda_id
LEFT JOIN ANGAJAT e2 ON lc.angajat_id = e2.angajat_id AND e2.rol = 'expeditor';

--- Operatie LMD permisa

UPDATE v_comenzi_detalii
SET status_comanda = 'livrată'
WHERE comanda_id = 12345;

--- Operatie LMD nepermisa

DELETE FROM v_comenzi_detalii
WHERE comanda_id = 12345;

--- Cerinta 15

--- Cererea ce utilizeaza operatia OUTER JOIN pe minimum 4 tabele

--- Dorim obținerea unei liste cu toate comenzile plasate de clienți, inclusiv cele care nu au produse asociate.
--- Informațiile incluse vor fi: ID-ul comenzii, numele clientului, denumirea produsului și cantitatea comandată.

SELECT c.comanda_id,
       cl.nume || ' ' || cl.prenume AS client,
       p.denumire AS produs,
       dc.cantitate
FROM COMANDA c
LEFT OUTER JOIN CLIENT cl ON c.client_id = cl.client_id
LEFT OUTER JOIN DETALII_COMANDA dc ON c.comanda_id = dc.comanda_id
LEFT OUTER JOIN PRODUS p ON dc.produs_id = p.produs_id
ORDER BY c.comanda_id;

--- Cererea ce utilizeaza operatia DIVISION

--- Se dorește afisarea tuturor clienților care au comandat toate produsele din categoria „Electronice”.
--- Rezultatul va include doar acei clienți care au achiziționat fiecare produs din aceasta categorie.

SELECT cl.client_id, cl.nume || ' ' || cl.prenume AS client
FROM CLIENT cl
WHERE NOT EXISTS (
    SELECT p.produs_id
    FROM PRODUS p
    WHERE p.categorie_id = (SELECT categorie_id FROM CATEGORIE WHERE nume = 'Electronice')
    AND NOT EXISTS (
        SELECT dc.produs_id
        FROM DETALII_COMANDA dc
        WHERE dc.comanda_id IN (SELECT c.comanda_id FROM COMANDA c WHERE c.client_id = cl.client_id)
        AND dc.produs_id = p.produs_id
    )
);

--- Cererea care implementeaza analiza TOP-N

--- Se doreste afisarea celor mai mari 5 clienti in functie de totalul comenzilor pe care le-au plasat.
--- Acestia vor fi selectati pe baza valorii totale a comenzilor, ordonate descrescător.

SELECT c.client_id, cl.nume || ' ' || cl.prenume AS client, SUM(c.total) AS total_comenzi
FROM COMANDA c
JOIN CLIENT cl ON c.client_id = cl.client_id
GROUP BY c.client_id, cl.nume, cl.prenume
ORDER BY total_comenzi DESC
FETCH FIRST 5 ROWS ONLY;


--- Cerinta 16

--- Sa presupunem ca vrem sa obtinem o lista cu produsele comandate de clienti, incluzand si pretul acestora si informatiile
--- despre furnizori, pentru comenzile care sunt „livrate” si pentru care pretul total al comenzii depaseste 1000 RON.

SELECT p.denumire, p.pret, f.denumire AS furnizor
FROM PRODUS p
JOIN DETALII_COMANDA dc ON p.produs_id = dc.produs_id
JOIN COMANDA c ON dc.comanda_id = c.comanda_id
JOIN FURNIZOR f ON p.furnizor_id = f.furnizor_id
WHERE c.status = 'livrata'
AND c.total > 1000;


EXPLAIN PLAN FOR
SELECT p.denumire, p.pret, f.denumire AS furnizor
FROM PRODUS p
JOIN DETALII_COMANDA dc ON p.produs_id = dc.produs_id
JOIN COMANDA c ON dc.comanda_id = c.comanda_id
JOIN FURNIZOR f ON p.furnizor_id = f.furnizor_id
WHERE c.status = 'livrata'
AND c.total > 1000;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY); --- pentru a vizualiza planul de executie

--- Optimizare cu hint-uri

SELECT /*+ USE_NL(p dc) */ p.denumire, p.pret, f.denumire AS furnizor
FROM PRODUS p
JOIN DETALII_COMANDA dc ON p.produs_id = dc.produs_id
JOIN COMANDA c ON dc.comanda_id = c.comanda_id
JOIN FURNIZOR f ON p.furnizor_id = f.furnizor_id
WHERE c.status = 'livrata'
AND c.total > 1000;

CREATE INDEX idx_comanda_status ON COMANDA(status);
CREATE INDEX idx_comanda_total ON COMANDA(total);
CREATE INDEX idx_produs_furnizor ON PRODUS(furnizor_id);



