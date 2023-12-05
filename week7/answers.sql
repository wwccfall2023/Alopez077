-- Create your tables, views, functions and procedures here!
CREATE SCHEMA destruction;
USE destruction;

CREATE TABLE players (
    player_id INT UNSIGNED PRIMARY KEY,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    email VARCHAR(255)
);
CREATE TABLE characters (
    character_id INT UNSIGNED PRIMARY KEY,
    player_id INT UNSIGNED,
    name VARCHAR(255),
    FOREIGN KEY (player_id) REFERENCES players(player_id)
);
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
    team_id INT UNSIGNED PRIMARY KEY,
    name VARCHAR(255)
);
CREATE TABLE team_members (
    team_member_id INT UNSIGNED PRIMARY KEY,
    team_id INT UNSIGNED,
    character_id INT UNSIGNED,
    FOREIGN KEY (team_id) REFERENCES teams(team_id),
    FOREIGN KEY (character_id) REFERENCES characters(character_id)
);
CREATE TABLE items (
    item_id INT UNSIGNED PRIMARY KEY,
    name VARCHAR(255),
    armor INT,
    damage INT
);
CREATE TABLE inventory (
    inventory_id INT UNSIGNED PRIMARY KEY,
    character_id INT UNSIGNED,
    item_id INT UNSIGNED,
    FOREIGN KEY (character_id) REFERENCES characters(character_id),
    FOREIGN KEY (item_id) REFERENCES items(item_id)
);
CREATE TABLE equipped (
    equipped_id INT UNSIGNED PRIMARY KEY,
    character_id INT UNSIGNED,
    item_id INT UNSIGNED,
    FOREIGN KEY (character_id) REFERENCES characters(character_id),
    FOREIGN KEY (item_id) REFERENCES items(item_id)
);
CREATE VIEW character_items AS
SELECT ch.character_id, ch.name AS character_name, i.name AS item_name, i.armor, i.damage
FROM characters ch
JOIN inventory inv ON ch.character_id = inv.character_id
JOIN items i ON inv.item_id = i.item_id
UNION
SELECT ch.character_id, ch.name AS character_name, i.name AS item_name, i.armor, i.damage
FROM characters ch
JOIN equipped eq ON ch.character_id = eq.character_id
JOIN items i ON eq.item_id = i.item_id;

CREATE VIEW team_items AS
SELECT tm.team_id, t.name AS team_name, i.name AS item_name, i.armor, i.damage
FROM teams t
JOIN team_members tm ON t.team_id = tm.team_id
JOIN characters ch ON tm.character_id = ch.character_id
JOIN inventory inv ON ch.character_id = inv.character_id
JOIN items i ON inv.item_id = i.item_id
UNION
SELECT tm.team_id, t.name AS team_name, i.name AS item_name, i.armor, i.damage
FROM teams t
JOIN team_members tm ON t.team_id = tm.team_id
JOIN characters ch ON tm.character_id = ch.character_id
JOIN equipped eq ON ch.character_id = eq.character_id
JOIN items i ON eq.item_id = i.item_id;

CREATE FUNCTION armor_total(character_id INT) RETURNS INT
DELIMITER //
BEGIN
    DECLARE total_armor INT;
    
    SELECT COALESCE(SUM(cs.armor), 0) + COALESCE(SUM(i.armor), 0) AS total
    INTO total_armor
    FROM character_stats cs
    JOIN equipped eq ON cs.character_id = eq.character_id
    JOIN items i ON eq.item_id = i.item_id
    WHERE cs.character_id = character_id;
    
    RETURN total_armor;
END;
DELIMITER ;

CREATE PROCEDURE attack(IN attacked_character_id INT, IN attacking_item_id INT)
DELIMITER //
BEGIN
    DECLARE total_armor INT;
    DECLARE total_damage INT;
    
    SET total_armor = armor_total(attacked_character_id);
    
    SELECT damage INTO total_damage
    FROM items
    WHERE item_id = attacking_item_id;
    
    SET total_damage = total_damage - total_armor;
    
    IF total_damage > 0 THEN
        UPDATE character_stats
        SET health = CASE
            WHEN health - total_damage > 0 THEN health - total_damage
            ELSE 0
            END
        WHERE character_id = attacked_character_id;
        
        DELETE FROM characters
        WHERE character_id = attacked_character_id AND health <= 0;
        
        -- Assuming cascading deletes are enabled for character-related tables to delete their possessions and team membership
    END IF;
END;
DELIMITER ;

CREATE PROCEDURE equip(IN inventory_item_id INT)
DELIMITER //
BEGIN
    DECLARE equipped_item_id INT;
    
    SELECT item_id INTO equipped_item_id
    FROM inventory
    WHERE inventory_id = inventory_item_id;
    
    INSERT INTO equipped (character_id, item_id)
    SELECT character_id, item_id
    FROM inventory
    WHERE inventory_id = inventory_item_id;
    
    DELETE FROM inventory
    WHERE inventory_id = inventory_item_id;
END;
DELIMITER ;

CREATE PROCEDURE unequip(IN equipped_item_id INT)
DELIMITER //
BEGIN
    DECLARE inventory_item_id INT;
    
    SELECT item_id INTO inventory_item_id
    FROM equipped
    WHERE equipped_id = equipped_item_id;
    
    INSERT INTO inventory (character_id, item_id)
    SELECT character_id, item_id
    FROM equipped
    WHERE equipped_id = equipped_item_id;
    
    DELETE FROM equipped
    WHERE equipped_id = equipped_item_id;
END;
DELIMITER ;
CREATE PROCEDURE set_winners(IN team_id INT)
DELIMITER //
BEGIN
    DELETE FROM winners;
    
    INSERT INTO winners (character_id)
    SELECT character_id
    FROM team_members
    WHERE team_id = team_id;
END;
DELIMITER ;
