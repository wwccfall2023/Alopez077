-- Create your tables, views, functions and procedures here!
CREATE SCHEMA destruction;
USE destruction;

CREATE TABLE players (
    player_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100)
);

CREATE TABLE characters (
    character_id INT AUTO_INCREMENT PRIMARY KEY,
    player_id INT,
    name VARCHAR(100),
    level INT,
    FOREIGN KEY (player_id) REFERENCES players(player_id)
);

CREATE TABLE winners (
    character_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    FOREIGN KEY (character_id) REFERENCES characters(character_id)
);

CREATE TABLE character_stats (
    character_id INT AUTO_INCREMENT PRIMARY KEY,
    health INT,
    armor INT,
    FOREIGN KEY (character_id) REFERENCES characters(character_id)
);

CREATE TABLE teams (
    team_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100)
);

CREATE TABLE team_members (
    team_member_id INT AUTO_INCREMENT PRIMARY KEY,
    team_id INT,
    character_id INT,
    FOREIGN KEY (team_id) REFERENCES teams(team_id),
    FOREIGN KEY (character_id) REFERENCES characters(character_id)
);

CREATE TABLE items (
    item_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    armor INT,
    damage INT
);

CREATE TABLE inventory (
    inventory_id INT AUTO_INCREMENT PRIMARY KEY,
    character_id INT,
    item_id INT,
    FOREIGN KEY (character_id) REFERENCES characters(character_id),
    FOREIGN KEY (item_id) REFERENCES items(item_id)
);

CREATE TABLE equipped (
    equipped_id INT AUTO_INCREMENT PRIMARY KEY,
    character_id INT,
    item_id INT,
    FOREIGN KEY (character_id) REFERENCES characters(character_id),
    FOREIGN KEY (item_id) REFERENCES items(item_id)
);

CREATE VIEW character_items AS
SELECT DISTINCT inv.character_id, c.name AS character_name, i.name AS item_name, i.armor, i.damage
FROM inventory inv
JOIN characters c ON inv.character_id = c.character_id
JOIN items i ON inv.item_id = i.item_id
UNION
SELECT DISTINCT eq.character_id, c.name AS character_name, i.name AS item_name, i.armor, i.damage
FROM equipped eq
JOIN characters c ON eq.character_id = c.character_id
JOIN items i ON eq.item_id = i.item_id;

CREATE VIEW team_items AS
SELECT tm.team_id, t.name AS team_name, i.name AS item_name, i.armor, i.damage
FROM team_members tm
JOIN teams t ON tm.team_id = t.team_id
JOIN characters c ON tm.character_id = c.character_id
JOIN inventory inv ON c.character_id = inv.character_id
JOIN items i ON inv.item_id = i.item_id
UNION
SELECT tm.team_id, t.name AS team_name, i.name AS item_name, i.armor, i.damage
FROM team_members tm
JOIN teams t ON tm.team_id = t.team_id
JOIN characters c ON tm.character_id = c.character_id
JOIN equipped eq ON c.character_id = eq.character_id
JOIN items i ON eq.item_id = i.item_id;

DELIMITER //
CREATE FUNCTION armor_total(character_id INT) RETURNS INT
BEGIN
    DECLARE total_armor INT;
    
    SELECT COALESCE(SUM(cs.armor), 0)
    INTO total_armor
    FROM character_stats cs
    WHERE cs.character_id = character_id;
    
    SELECT COALESCE(SUM(i.armor), 0)
    INTO total_armor
    FROM equipped eq
    JOIN items i ON eq.item_id = i.item_id
    WHERE eq.character_id = character_id;
    
    RETURN total_armor;
END;
DELIMITER ;

DELIMITER //
CREATE PROCEDURE attack(id_of_character_being_attacked INT, id_of_equipped_item_used_for_attack INT)
BEGIN
    DECLARE total_armor INT;
    DECLARE total_damage INT;
    DECLARE char_health INT;
    
    SET total_armor = armor_total(id_of_character_being_attacked);
    
    SELECT damage INTO total_damage
    FROM items
    WHERE item_id = id_of_equipped_item_used_for_attack;
    
    SELECT health INTO char_health
    FROM character_stats
    WHERE character_id = id_of_character_being_attacked;
    
    IF (total_damage - total_armor) > 0 THEN
        UPDATE character_stats
        SET health = health - (total_damage - total_armor)
        WHERE character_id = id_of_character_being_attacked;
        
        IF (health - (total_damage - total_armor)) <= 0 THEN
            DELETE FROM characters WHERE character_id = id_of_character_being_attacked;
            DELETE FROM inventory WHERE character_id = id_of_character_being_attacked;
            DELETE FROM equipped WHERE character_id = id_of_character_being_attacked;
            DELETE FROM team_members WHERE character_id = id_of_character_being_attacked;
            DELETE FROM winners WHERE character_id = id_of_character_being_attacked;
        END IF;
    END IF;
END;
DELIMITER ;

DELIMITER //
CREATE PROCEDURE equip(inventory_id INT)
BEGIN
    DECLARE item_id INT;
    DECLARE char_id INT;
    
    SELECT character_id, item_id INTO char_id, item_id
    FROM inventory
    WHERE inventory_id = inventory_id;
    
    INSERT INTO equipped (character_id, item_id)
    VALUES (char_id, item_id);
    
    DELETE FROM inventory WHERE inventory_id = inventory_id;
END;
DELIMITER ;

DELIMITER //
CREATE PROCEDURE unequip(equipped_id INT)
BEGIN
    DECLARE item_id INT;
    DECLARE char_id INT;
    
    SELECT character_id, item_id INTO char_id, item_id
    FROM equipped
    WHERE equipped_id = equipped_id;
    
    INSERT INTO inventory (character_id, item_id)
    VALUES (char_id, item_id);
    
    DELETE FROM equipped WHERE equipped_id = equipped_id;
END;
DELIMITER ;

DELIMITER //

CREATE PROCEDURE set_winners(IN team_id INT)
BEGIN
    -- Delete existing winners from the specified team
    DELETE FROM winners WHERE character_id IN (
        SELECT character_id
        FROM team_members
        WHERE team_id = team_id
    );

    -- Insert new winners from the specified team
    INSERT INTO winners (character_id, name)
    SELECT tm.character_id, c.name
    FROM team_members tm
    JOIN characters c ON tm.character_id = c.character_id
    WHERE tm.team_id = team_id;
END //

DELIMITER ;






