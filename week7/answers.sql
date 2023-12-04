-- Create your tables, views, functions and procedures here!
CREATE SCHEMA destruction;
USE destruction;

CREATE TABLE players (
    player_id INT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT,
    first_name VARCHAR(30) NOT NULL,
    last_name VARCHAR(30) NOT NULL,
    email VARCHAR(50) NOT NULL
);

CREATE TABLE characters (
    character_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    player_id INT UNSIGNED,
    name VARCHAR(50),
    level INT
);
ALTER TABLE characters
    ADD FOREIGN KEY (player_id) REFERENCES players(player_id);

CREATE TABLE winners (
    character_id INT UNSIGNED PRIMARY KEY,
    FOREIGN KEY (character_id) REFERENCES characters(character_id)
);

CREATE TABLE character_stats (
    character_id INT UNSIGNED PRIMARY KEY,
    health INT,
    armor INT,
    FOREIGN KEY (character_id) REFERENCES characters(character_id)
);

CREATE TABLE teams (
    team_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50)
);

CREATE TABLE team_members (
    team_member_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    team_id INT UNSIGNED,
    character_id INT UNSIGNED,
    FOREIGN KEY (team_id) REFERENCES teams(team_id),
    FOREIGN KEY (character_id) REFERENCES characters(character_id)
);

CREATE TABLE items (
    item_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50),
    armor INT,
    damage INT
);

CREATE TABLE inventory (
    inventory_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    character_id INT UNSIGNED,
    item_id INT UNSIGNED,
    FOREIGN KEY (character_id) REFERENCES characters(character_id),
    FOREIGN KEY (item_id) REFERENCES items(item_id)
);

CREATE TABLE equipped (
    equipped_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    character_id INT UNSIGNED,
    item_id INT UNSIGNED,
    FOREIGN KEY (character_id) REFERENCES characters(character_id),
    FOREIGN KEY (item_id) REFERENCES items(item_id)
);

CREATE OR REPLACE VIEW character_items AS
SELECT c.character_id, c.name AS character_name, i.name AS item_name, i.armor, i.damage
FROM characters c
LEFT JOIN inventory inv ON c.character_id = inv.character_id
LEFT JOIN equipped eq ON c.character_id = eq.character_id
LEFT JOIN items i ON inv.item_id = i.item_id OR eq.item_id = i.item_id;

CREATE OR REPLACE VIEW team_items AS
SELECT tm.team_id, t.name AS team_name, i.name AS item_name, i.armor, i.damage
FROM team_members tm
JOIN teams t ON tm.team_id = t.team_id
LEFT JOIN characters c ON tm.character_id = c.character_id
LEFT JOIN inventory inv ON c.character_id = inv.character_id
LEFT JOIN equipped eq ON c.character_id = eq.character_id
LEFT JOIN items i ON inv.item_id = i.item_id OR eq.item_id = i.item_id;

DELIMITER //

CREATE OR REPLACE FUNCTION armor_total(character_id INT UNSIGNED) RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE total_armor INT;
    
    SELECT COALESCE(SUM(cs.armor), 0) INTO total_armor
    FROM character_stats cs
    WHERE cs.character_id = character_id;

    SELECT COALESCE(SUM(i.armor), 0) INTO total_armor
    FROM equipped eq
    JOIN items i ON eq.item_id = i.item_id
    WHERE eq.character_id = character_id;

    RETURN total_armor;
END //

CREATE PROCEDURE attack(IN id_of_character_being_attacked INT UNSIGNED, IN id_of_equipped_item_used_for_attack INT UNSIGNED)
BEGIN
    DECLARE character_armor INT;
    DECLARE item_damage INT;
    DECLARE total_damage INT;

    SET character_armor = armor_total(id_of_character_being_attacked);

    SELECT i.damage INTO item_damage
    FROM equipped eq
    JOIN items i ON eq.item_id = i.item_id
    WHERE eq.equipped_id = id_of_equipped_item_used_for_attack;

    SET total_damage = item_damage - character_armor;

    IF total_damage > 0 THEN
        UPDATE character_stats
        SET health = CASE WHEN health - total_damage > 0 THEN health - total_damage ELSE 0 END
        WHERE character_id = id_of_character_being_attacked;

        IF health = 0 THEN
            DELETE FROM characters WHERE character_id = id_of_character_being_attacked;
            DELETE FROM team_members WHERE character_id = id_of_character_being_attacked;
            DELETE FROM winners WHERE character_id = id_of_character_being_attacked;
        END IF;
    END IF;        
END //

CREATE PROCEDURE equip(IN inventory_id INT UNSIGNED)
BEGIN
    DECLARE item_id_to_equip INT UNSIGNED;

    SELECT item_id INTO item_id_to_equip
    FROM inventory
    WHERE inventory_id = inventory_id;

    INSERT INTO equipped (character_id, item_id)
    SELECT character_id, item_id
    FROM inventory
    WHERE inventory_id = inventory_id;

    DELETE FROM inventory
    WHERE inventory_id = inventory_id;
END //

CREATE PROCEDURE unequip(IN equipped_id INT UNSIGNED)
BEGIN
    DECLARE item_id_to_unequip INT UNSIGNED;

    SELECT item_id INTO item_id_to_unequip
    FROM equipped
    WHERE equipped_id = equipped_id;

    INSERT INTO inventory (character_id, item_id)
    SELECT character_id, item_id
    FROM equipped
    WHERE equipped_id = equipped_id;

    DELETE FROM equipped
    WHERE equipped_id = equipped_id;
END //

CREATE PROCEDURE set_winners(IN team_id INT UNSIGNED)
BEGIN
    DELETE FROM winners;
    INSERT INTO winners (character_id)
    SELECT tm.character_id
    FROM team_members tm
    WHERE tm.team_id = team_id;
END //
DELIMITER ;
