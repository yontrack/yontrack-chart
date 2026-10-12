-- Expand migration of the upgrade test: run at startup, while the previous version still serves
CREATE TABLE UPGRADE_TEST_LEGACY
(
    ID INTEGER PRIMARY KEY
);
