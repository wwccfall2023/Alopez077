-- Create your tables, views, functions and procedures here!
CREATE SCHEMA destruction;
USE destruction;

-- Tables

-- Players Table
CREATE TABLE players (
    player_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100)
);

-- Characters Table
CREATE TABLE characters (
    character_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    player_id INT UNSIGNED,
    name VARCHAR(50),
    level INT,
    FOREIGN KEY (player_id) REFERENCES players(player_id)
);

-- Winners Table
CREATE TABLE winners (
    character_id INT UNSIGNED PRIMARY KEY,
    FOREIGN KEY (character_id) REFERENCES characters(character_id)
);

-- Character Stats Table
CREATE TABLE character_stats (
    character_id INT UNSIGNED PRIMARY KEY,
    health INT,
    armor INT,
    FOREIGN KEY (character_id) REFERENCES characters(character_id)
);

-- Teams Table
CREATE TABLE teams (
    team_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50)
);

-- Team Members Table
CREATE TABLE team_members (
    team_member_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    team_id INT UNSIGNED,
    character_id INT UNSIGNED,
    FOREIGN KEY (team_id) REFERENCES teams(team_id),
    FOREIGN KEY (character_id) REFERENCES characters(character_id)
);

-- Items Table
CREATE TABLE items (
    item_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50),
    armor INT,
    damage INT
);

-- Inventory Table
CREATE TABLE inventory (
    inventory_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    character_id INT UNSIGNED,
    item_id INT UNSIGNED,
    FOREIGN KEY (character_id) REFERENCES characters(character_id),
    FOREIGN KEY (item_id) REFERENCES items(item_id)
);

-- Equipped Table
CREATE TABLE equipped (
    equipped_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    character_id INT UNSIGNED,
    item_id INT UNSIGNED,
    FOREIGN KEY (character_id) REFERENCES characters(character_id),
    FOREIGN KEY (item_id) REFERENCES items(item_id)
);

-- Views

-- character_items View
CREATE VIEW character_items AS
SELECT c.character_id, c.name AS character_name, i.name AS item_name, i.armor AS item_armor, i.damage AS item_damage
FROM characters c
LEFT JOIN inventory inv ON c.character_id = inv.character_id
LEFT JOIN items i ON inv.item_id = i.item_id
UNION
SELECT c.character_id, c.name AS character_name, i.name AS item_name, i.armor AS item_armor, i.damage AS item_damage
FROM characters c
LEFT JOIN equipped eq ON c.character_id = eq.character_id
LEFT JOIN items i ON eq.item_id = i.item_id;

-- team_items View
CREATE VIEW team_items AS
SELECT tm.team_id, t.name AS team_name, i.name AS item_name, i.armor AS item_armor, i.damage AS item_damage
FROM team_members tm
JOIN teams t ON tm.team_id = t.team_id
JOIN characters c ON tm.character_id = c.character_id
LEFT JOIN inventory inv ON c.character_id = inv.character_id
LEFT JOIN items i ON inv.item_id = i.item_id
UNION
SELECT tm.team_id, t.name AS team_name, i.name AS item_name, i.armor AS item_armor, i.damage AS item_damage
FROM team_members tm
JOIN teams t ON tm.team_id = t.team_id
JOIN characters c ON tm.character_id = c.character_id
LEFT JOIN equipped eq ON c.character_id = eq.character_id
LEFT JOIN items i ON eq.item_id = i.item_id;

-- Functions

-- armor_total Function
DELIMITER //
CREATE FUNCTION armor_total(character_id_param INT UNSIGNED) RETURNS INT
BEGIN
    DECLARE total_armor INT;
    SELECT COALESCE(SUM(cs.armor) + SUM(i.armor), 0) INTO total_armor
    FROM character_stats cs
    JOIN equipped eq ON cs.character_id = eq.character_id
    JOIN items i ON eq.item_id = i.item_id
    WHERE cs.character_id = character_id_param;
    RETURN total_armor;
END //
DELIMITER ;

-- Procedures

-- attack Procedure
DELIMITER //
CREATE PROCEDURE attack(id_of_character_being_attacked INT UNSIGNED, id_of_equipped_item_used_for_attack INT UNSIGNED)
BEGIN
    DECLARE character_armor INT;
    DECLARE item_damage INT;
    
    SELECT armor_total(id_of_character_being_attacked) INTO character_armor;
    SELECT damage INTO item_damage FROM items WHERE item_id = id_of_equipped_item_used_for_attack;
    
    DECLARE net_damage INT;
    SET net_damage = item_damage - character_armor;
    
    IF net_damage > 0 THEN
        UPDATE character_stats SET health = health - net_damage WHERE character_id = id_of_character_being_attacked;
        IF (SELECT health FROM character_stats WHERE character_id = id_of_character_being_attacked) <= 0 THEN
            DELETE FROM characters WHERE character_id = id_of_character_being_attacked;
            DELETE FROM team_members WHERE character_id = id_of_character_being_attacked;
            -- Delete other related data or perform additional actions as needed
        END IF;
    END IF;
END //
DELIMITER ;

-- equip Procedure
DELIMITER //
CREATE PROCEDURE equip(inventory_id_param INT UNSIGNED)
BEGIN
    DECLARE item_id_to_equip INT UNSIGNED;
    SELECT item_id INTO item_id_to_equip FROM inventory WHERE inventory_id = inventory_id_param;
    INSERT INTO equipped (character_id, item_id) SELECT character_id, item_id FROM inventory WHERE inventory_id = inventory_id_param;
    DELETE FROM inventory WHERE inventory_id = inventory_id_param;
END //
DELIMITER ;

-- unequip Procedure
DELIMITER //
CREATE PROCEDURE unequip(equipped_id_param INT UNSIGNED)
BEGIN
    DECLARE item_id_to_unequip INT UNSIGNED;
    SELECT item_id INTO item_id_to_unequip FROM equipped WHERE equipped_id = equipped_id_param;
    INSERT INTO inventory (character_id, item_id) SELECT character_id, item_id FROM equipped WHERE equipped_id = equipped_id_param;
    DELETE FROM equipped WHERE equipped_id = equipped_id_param;
END //
DELIMITER ;

-- set_winners Procedure
DELIMITER //
CREATE PROCEDURE set_winners(team_id_param INT UNSIGNED)
BEGIN
    DELETE FROM winners;
    -- Insert logic to update winners table with characters in the specified team
    -- Use INSERT INTO winners SELECT... to add the relevant character_ids
END //
DELIMITER ;
