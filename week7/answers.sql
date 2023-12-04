-- Create your tables, views, functions and procedures here!
CREATE SCHEMA destruction;
USE destruction;

CREATE TABLE players (
    player_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100)
);

CREATE TABLE characters (
    character_id INT PRIMARY KEY,
    player_id INT,
    name VARCHAR(50),
    level INT,
    FOREIGN KEY (player_id) REFERENCES players(player_id)
);

CREATE TABLE winners (
    character_id INT PRIMARY KEY,
    FOREIGN KEY (character_id) REFERENCES characters(character_id)
);

CREATE TABLE character_stats (
    character_id INT PRIMARY KEY,
    health INT,
    armor INT,
    FOREIGN KEY (character_id) REFERENCES characters(character_id)
);

CREATE TABLE teams (
    team_id INT PRIMARY KEY,
    name VARCHAR(50)
);

CREATE TABLE team_members (
    team_member_id INT PRIMARY KEY,
    team_id INT,
    character_id INT,
    FOREIGN KEY (team_id) REFERENCES teams(team_id),
    FOREIGN KEY (character_id) REFERENCES characters(character_id)
);

CREATE TABLE items (
    item_id INT PRIMARY KEY,
    name VARCHAR(50),
    armor INT,
    damage INT
);

CREATE TABLE inventory (
    inventory_id INT PRIMARY KEY,
    character_id INT,
    item_id INT,
    FOREIGN KEY (character_id) REFERENCES characters(character_id),
    FOREIGN KEY (item_id) REFERENCES items(item_id)
);

CREATE TABLE equipped (
    equipped_id INT PRIMARY KEY,
    character_id INT,
    item_id INT,
    FOREIGN KEY (character_id) REFERENCES characters(character_id),
    FOREIGN KEY (item_id) REFERENCES items(item_id)
);

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

CREATE FUNCTION armor_total(character_id INT) RETURNS INT READS SQL DATA
BEGIN
    DECLARE total_armor INT;
    SELECT COALESCE(SUM(cs.armor) + SUM(i.armor), 0)
    INTO total_armor
    FROM character_stats cs
    JOIN equipped eq ON cs.character_id = eq.character_id
    JOIN items i ON eq.item_id = i.item_id
    WHERE cs.character_id = character_id;
    RETURN total_armor;
END;

CREATE PROCEDURE attack(id_of_character_being_attacked INT, id_of_equipped_item_used_for_attack INT)
BEGIN
    DECLARE character_armor INT;
    DECLARE item_damage INT;
    DECLARE net_damage INT;
    
    SELECT armor_total(id_of_character_being_attacked) INTO character_armor;
    SELECT damage INTO item_damage FROM items WHERE item_id = id_of_equipped_item_used_for_attack;
    
    SET net_damage = item_damage - character_armor;
    
    IF net_damage > 0 THEN
        UPDATE character_stats SET health = health - net_damage WHERE character_id = id_of_character_being_attacked;
        IF (SELECT health FROM character_stats WHERE character_id = id_of_character_being_attacked) <= 0 THEN
            DELETE FROM characters WHERE character_id = id_of_character_being_attacked;
            DELETE FROM team_members WHERE character_id = id_of_character_being_attacked;
            -- Delete other related data or perform additional actions as needed
        END IF;
    END IF;
END;

CREATE PROCEDURE equip(inventory_id INT)
BEGIN
    DECLARE item_id_to_equip INT;
    SELECT item_id INTO item_id_to_equip FROM inventory WHERE inventory_id = inventory_id;
    INSERT INTO equipped (character_id, item_id) SELECT character_id, item_id FROM inventory WHERE inventory_id = inventory_id;
    DELETE FROM inventory WHERE inventory_id = inventory_id;
END;

CREATE PROCEDURE unequip(equipped_id INT)
BEGIN
    DECLARE item_id_to_unequip INT;
    SELECT item_id INTO item_id_to_unequip FROM equipped WHERE equipped_id = equipped_id;
    INSERT INTO inventory (character_id, item_id) SELECT character_id, item_id FROM equipped WHERE equipped_id = equipped_id;
    DELETE FROM equipped WHERE equipped_id = equipped_id;
END;

CREATE PROCEDURE set
