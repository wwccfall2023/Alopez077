-- Create your tables, views, functions and procedures here!
CREATE SCHEMA social;
USE social;


CREATE TABLE users (
    user_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    created_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE sessions (
    session_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED,
    created_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

CREATE TABLE friends (
    user_friend_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED,
    friend_id INT UNSIGNED,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (friend_id) REFERENCES users(user_id)
);

CREATE TABLE posts (
    post_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED,
    created_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    content TEXT,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

CREATE TABLE notifications (
    notification_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED,
    post_id INT UNSIGNED,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (post_id) REFERENCES posts(post_id)
);

CREATE VIEW notification_posts AS
SELECT n.user_id AS notification_user_id, 
       u.first_name, 
       u.last_name, 
       p.post_id, 
       p.content
FROM notifications n
LEFT JOIN users u ON n.user_id = u.user_id
LEFT JOIN posts p ON n.post_id = p.post_id;

DELIMITER //
CREATE TRIGGER new_user_notification AFTER INSERT ON users
FOR EACH ROW
BEGIN
    DECLARE message VARCHAR(255);
    SET message = CONCAT(NEW.first_name, ' ', NEW.last_name, ' just joined!');

    INSERT INTO notifications (user_id, post_id)
    SELECT user_id, NULL FROM users WHERE user_id != NEW.user_id;

    UPDATE notifications
    SET content = message
    WHERE user_id != NEW.user_id AND post_id IS NULL;
END;
//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE remove_stale_sessions()
BEGIN
    DELETE FROM sessions
    WHERE updated_on < NOW() - INTERVAL 2 HOUR;
END;
//
DELIMITER ;

-- Creating an Event to Run Every 10 Seconds
CREATE EVENT IF NOT EXISTS remove_old_sessions_event
ON SCHEDULE EVERY 10 SECOND
DO CALL remove_stale_sessions();

DELIMITER //

CREATE PROCEDURE add_post(IN user_id INT, IN post_content TEXT)
BEGIN
    DECLARE friend_id INT;
    DECLARE done BOOLEAN DEFAULT FALSE;
    DECLARE cur_friends CURSOR FOR
        SELECT friend_id FROM friends WHERE user_id = user_id;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    INSERT INTO posts (user_id, content) VALUES (user_id, post_content);
    SET @new_post_id = LAST_INSERT_ID();
    
    OPEN cur_friends;
    read_loop: LOOP
        FETCH cur_friends INTO friend_id;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        INSERT INTO notifications (user_id, post_id, content)
        VALUES (friend_id, @new_post_id, CONCAT(
            (SELECT first_name FROM users WHERE user_id = user_id),
            ' posted: ', post_content)
        );
    END LOOP;
    CLOSE cur_friends;
END;
//
DELIMITER ;
