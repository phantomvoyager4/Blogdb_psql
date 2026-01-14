-- PostgreSQL database dump

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET default_tablespace = '';
SET default_with_oids = false;

--- drop tables

DROP TABLE IF EXISTS Likes;
DROP TABLE IF EXISTS Followers;
DROP TABLE IF EXISTS Post_Tags;
DROP TABLE IF EXISTS Comments;
DROP TABLE IF EXISTS Posts;
DROP TABLE IF EXISTS Tags;
DROP TABLE IF EXISTS Categories;
DROP TABLE IF EXISTS Users;
DROP TABLE IF EXISTS Roles;

-- Name: Roles; Type: TABLE; Schema: public; Owner: -; Tablespace: 

CREATE TABLE Roles (
    role_id serial primary key,
    role_name varchar(255) unique not null
);

-- Name: Categories; Type: TABLE; Schema: public; Owner: -; Tablespace: 

CREATE TABLE Categories (
    category_id serial primary key,
    category varchar(255) unique not null,
    post_count integer default 0
);

-- Name: Tags; Type: TABLE; Schema: public; Owner: -; Tablespace: 

CREATE TABLE Tags (
    tag_id serial primary key,
    tag_name varchar(255) unique not null
);

-- Name: Users; Type: TABLE; Schema: public; Owner: -; Tablespace: 

CREATE TABLE Users (
    user_id serial primary key not null,
    role_id integer not null references Roles(role_id),
    email varchar(255) unique not null,
    username varchar(255) not null,
    birthdate date,
    password varchar(255) not null,
    created_at timestamp default current_timestamp,
    check (char_length(email) > 5),
    check (char_length(username) >= 3 and char_length(username) <= 50),
    check (char_length(password) >= 8)
);

-- Name: Posts; Type: TABLE; Schema: public; Owner: -; Tablespace: 

CREATE TABLE Posts (
    post_id serial primary key,
    user_id integer not null references Users(user_id) on delete cascade,
    category_id integer references Categories(category_id) on delete set null,
    title text not null,
    content text not null,
    created_at timestamp default current_timestamp,
    likes_count integer default 0
);

-- Name: Comments; Type: TABLE; Schema: public; Owner: -; Tablespace: 

CREATE TABLE Comments (
    comment_id serial primary key,
    parent_comment_id integer references Comments(comment_id) on delete cascade,
    post_id integer not null references Posts(post_id) on delete cascade,
    user_id integer not null references Users(user_id) on delete cascade,
    content text not null,
    created_at timestamp default current_timestamp,
    likes_count integer default 0
);

CREATE TABLE Comment_Likes (
    like_id SERIAL PRIMARY KEY,
    comment_id INTEGER NOT NULL REFERENCES Comments(comment_id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(comment_id, user_id)
);

-- Name: Post_Tags; Type: TABLE; Schema: public; Owner: -; Tablespace: 

CREATE TABLE Post_Tags (
    tag_id integer not null references Tags(tag_id) on delete cascade,
    post_id integer not null references Posts(post_id) on delete cascade,
    primary key (post_id, tag_id)
);

-- Name: Followers; Type: TABLE; Schema: public; Owner: -; Tablespace: 

CREATE TABLE Followers (
    follower_id integer not null references Users(user_id) on delete cascade,
    followed_id integer not null references Users(user_id) on delete cascade,
    check (followed_id != follower_id),
    primary key (follower_id, followed_id)
);

-- Name: Likes; Type: TABLE; Schema: public; Owner: -; Tablespace: 

CREATE TABLE Likes (
    like_id serial primary key,
    post_id integer not null references Posts(post_id) on delete cascade,
    user_id integer not null references Users(user_id) on delete cascade,
    created_at timestamp default current_timestamp,
    unique(post_id, user_id)
);

CREATE INDEX idx_posts_user_id ON Posts(user_id);
CREATE INDEX idx_posts_category_id ON Posts(category_id);
CREATE INDEX idx_comments_post_id ON Comments(post_id);
CREATE INDEX idx_comments_user_id ON Comments(user_id);
CREATE INDEX idx_comments_parent_id ON Comments(parent_comment_id);
CREATE INDEX idx_post_tags_tag_id ON Post_Tags(tag_id);
CREATE INDEX idx_post_tags_post_id ON Post_Tags(post_id);
CREATE INDEX idx_followers_follower_id ON Followers(follower_id);
CREATE INDEX idx_followers_followed_id ON Followers(followed_id);
CREATE INDEX idx_likes_post_id ON Likes(post_id);
CREATE INDEX idx_likes_user_id ON Likes(user_id);
CREATE INDEX idx_comment_likes_comment_id ON Comment_Likes(comment_id);
CREATE INDEX idx_comment_likes_user_id ON Comment_Likes(user_id);

COMMENT ON TABLE Roles IS 'User roles for access control (Admin, Moderator, User)';
COMMENT ON TABLE Users IS 'User accounts with email, username, and assigned roles with validation constraints';
COMMENT ON COLUMN Users.created_at IS 'Account creation timestamp';
COMMENT ON COLUMN Users.email IS 'User email (must be at least 6 characters)';
COMMENT ON COLUMN Users.username IS 'User display name (3-50 characters)';
COMMENT ON COLUMN Users.password IS 'Hashed password (minimum 8 characters)';
COMMENT ON COLUMN Users.role_id IS 'References user role for permission management';
COMMENT ON TABLE Categories IS 'Blog post categories with auto-updated post count via trigger';
COMMENT ON TABLE Tags IS 'Tags for categorizing and organizing posts';
COMMENT ON TABLE Posts IS 'Blog posts with content, timestamps, and like counts';
COMMENT ON COLUMN Posts.likes_count IS 'Denormalized count; actual likes tracked in Likes table';
COMMENT ON TABLE Comments IS 'Comments on posts with support for nested replies (parent_comment_id). Likes tracked in Comment_Likes table';
COMMENT ON COLUMN Comments.parent_comment_id IS 'References parent comment for nested replies; NULL if top-level comment';
COMMENT ON COLUMN Comments.likes_count IS 'Denormalized count; actual likes tracked in Comment_Likes table';
COMMENT ON TABLE Comment_Likes IS 'Tracks individual user likes on comments with timestamps';
COMMENT ON TABLE Post_Tags IS 'Junction table linking posts to multiple tags (many-to-many)';
COMMENT ON TABLE Likes IS 'Tracks individual user likes on posts with timestamps';
COMMENT ON TABLE Followers IS 'User-to-user follow relationships for social features';


-- TRIGGER FOR AUTO-UPDATING POST COUNT 
CREATE OR REPLACE FUNCTION update_post_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE Categories SET post_count = post_count + 1 WHERE category_id = NEW.category_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE Categories SET post_count = post_count - 1 WHERE category_id = OLD.category_id;
    RETURN OLD;
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.category_id != OLD.category_id THEN
      UPDATE Categories SET post_count = post_count - 1 WHERE category_id = OLD.category_id;
      UPDATE Categories SET post_count = post_count + 1 WHERE category_id = NEW.category_id;
    END IF;
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER post_count_trigger
AFTER INSERT OR DELETE OR UPDATE ON Posts
FOR EACH ROW
EXECUTE FUNCTION update_post_count();

-- TRIGGER FOR AUTO-UPDATING COMMENT LIKE COUNT
CREATE OR REPLACE FUNCTION update_comment_like_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE Comments SET likes_count = likes_count + 1 WHERE comment_id = NEW.comment_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE Comments SET likes_count = likes_count - 1 WHERE comment_id = OLD.comment_id;
    RETURN OLD;
  END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER comment_like_count_trigger
AFTER INSERT OR DELETE ON Comment_Likes
FOR EACH ROW
EXECUTE FUNCTION update_comment_like_count();

-- TRIGGER FOR AUTO-UPDATING POST LIKE COUNT
CREATE OR REPLACE FUNCTION update_post_like_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE Posts SET likes_count = likes_count + 1 WHERE post_id = NEW.post_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE Posts SET likes_count = likes_count - 1 WHERE post_id = OLD.post_id;
    RETURN OLD;
  END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER post_like_count_trigger
AFTER INSERT OR DELETE ON Likes
FOR EACH ROW
EXECUTE FUNCTION update_post_like_count();

-- Inserting data to our database
-- Data has been generated using Artificial Intelligence

-- Data for Name: Roles; Type: TABLE DATA; Schema: public; Owner: -

INSERT INTO Roles (role_name) VALUES
('Admin'),
('Moderator'),
('User');

-- Data for Name: Users; Type: TABLE DATA; Schema: public; Owner: -

INSERT INTO Users (role_id, email, username, birthdate, password) VALUES
(1, 'admin@blog.com', 'admin_user', '1990-05-15', 'hashed_password_1'),
(2, 'moderator@blog.com', 'mod_jane', '1992-08-20', 'hashed_password_2'),
(3, 'john@blog.com', 'john_doe', '1995-03-10', 'hashed_password_3'),
(3, 'sarah@blog.com', 'sarah_smith', '1998-07-22', 'hashed_password_4'),
(3, 'mike@blog.com', 'mike_tech', '1993-11-05', 'hashed_password_5'),
(3, 'emma@blog.com', 'emma_writer', '1996-02-14', 'hashed_password_6'),
(3, 'david@blog.com', 'david_coder', '1994-09-30', 'hashed_password_7'),
(3, 'lisa@blog.com', 'lisa_design', '1997-06-18', 'hashed_password_8'),
(3, 'alex@blog.com', 'alex_gamer', '1999-01-25', 'hashed_password_9'),
(3, 'chris@blog.com', 'chris_blogger', '1991-12-08', 'hashed_password_10');

-- Data for Name: Categories; Type: TABLE DATA; Schema: public; Owner: -

INSERT INTO Categories (category, post_count) VALUES
('Technology', 0),
('Travel', 0),
('Food', 0),
('Lifestyle', 0),
('Business', 0),
('Gaming', 0);

-- Data for Name: Tags; Type: TABLE DATA; Schema: public; Owner: -

INSERT INTO Tags (tag_name) VALUES
('tutorial'),
('beginner'),
('advanced'),
('tips'),
('review'),
('inspiration'),
('adventure'),
('productivity'),
('coding'),
('javascript'),
('python'),
('web-development'),
('database'),
('recipes'),
('health'),
('fitness');

-- Data for Name: Posts; Type: TABLE DATA; Schema: public; Owner: -

INSERT INTO Posts (user_id, category_id, title, content, created_at, likes_count) VALUES
(1, 1, 'Welcome to Our Blog Platform', 'Excited to announce the launch of our new blog platform! This is a modern, scalable solution built with PostgreSQL...', '2025-01-16 08:00:00', 234),
(1, 5, 'Platform Updates and Roadmap', 'Here''s what we''re planning for the next quarter. We''re focusing on performance, user experience, and new features...', '2025-01-14 12:30:00', 156),
(1, 1, 'Database Best Practices for Developers', 'As the admin, I wanted to share some essential database practices we use on this platform. Normalization, indexing, and more...', '2025-01-10 15:45:00', 189),
(2, 5, 'Community Guidelines and Moderation', 'Important rules for maintaining a healthy community. We''re committed to providing a safe and respectful space for all users...', '2025-01-15 10:20:00', 98),
(2, 1, 'New Feature: Post Tagging System', 'We''ve just rolled out our new tagging system! This makes it easier to organize and discover content across our blog...', '2025-01-12 14:00:00', 167),
(3, 1, 'Getting Started with PostgreSQL', 'PostgreSQL is a powerful open-source relational database. In this tutorial, we will explore the basics...', '2025-01-15 10:30:00', 45),
(5, 1, 'JavaScript ES6 Features Explained', 'ES6 brought many new features to JavaScript. Let''s dive into arrow functions, promises, and async/await...', '2025-01-14 14:20:00', 78),
(6, 2, 'My Amazing Trip to Tokyo', 'Just returned from an incredible journey through Tokyo. The temples, food, and culture are amazing...', '2025-01-13 09:15:00', 125),
(4, 3, 'Quick and Easy Pasta Recipes', 'Looking for a simple dinner? Try these quick pasta recipes that take less than 30 minutes...', '2025-01-12 18:45:00', 92),
(7, 1, 'Building RESTful APIs with Node.js', 'Learn how to create scalable APIs using Node.js and Express. We''ll cover routing, middleware, and best practices...', '2025-01-11 11:00:00', 156),
(5, 6, 'Top 10 Games of 2024', 'Here are my favorite games released in 2024. From indie gems to AAA blockbusters...', '2025-01-10 16:30:00', 203),
(8, 4, 'Morning Routine for Productivity', 'Start your day right with these 5 simple habits that will boost your productivity...', '2025-01-09 07:00:00', 67),
(3, 1, 'Database Design Best Practices', 'Designing a good database schema is crucial. Let''s talk about normalization, indexes, and relationships...', '2025-01-08 13:20:00', 88),
(6, 2, 'Hidden Gems in Paris', 'Beyond the Eiffel Tower, Paris has incredible hidden spots. Discover secret cafes and galleries...', '2025-01-07 10:45:00', 134),
(9, 5, 'Building a Successful Startup', 'What it takes to launch and grow a successful startup. Lessons from experience and research...', '2025-01-06 15:30:00', 95),
(4, 3, 'Healthy Meal Prep Ideas', 'Prepare meals for the week with these healthy and delicious recipes. Save time and stay fit...', '2025-01-05 12:00:00', 112),
(7, 1, 'Introduction to Machine Learning', 'Machine Learning is transforming industries. Let''s start with the fundamentals...', '2025-01-04 14:15:00', 167),
(10, 4, 'Minimalism: Living with Less', 'How to simplify your life and focus on what really matters. Tips for decluttering and mindfulness...', '2025-01-03 08:30:00', 78),
(5, 1, 'React Hooks Deep Dive', 'React Hooks changed how we write components. Let''s explore useState, useEffect, and custom hooks...', '2025-01-02 11:45:00', 145),
(8, 2, 'Budget Travel Tips', 'Travel the world on a budget. Cheap flights, accommodations, and experiences...', '2025-01-01 09:00:00', 156),
(3, 1, 'Python Web Scraping Tutorial', 'Learn how to scrape websites ethically using Python. We''ll use BeautifulSoup and requests library...', '2024-12-31 10:15:00', 134),
(5, 5, 'Scaling Your Business to 100k Users', 'How to handle growth and scale your business infrastructure. Database optimization, caching, and more...', '2024-12-30 14:00:00', 178),
(4, 3, 'Chocolate Chip Cookie Perfection', 'The ultimate guide to baking the perfect chocolate chip cookies. Tips for crispy edges and chewy centers...', '2024-12-29 16:45:00', 89),
(7, 1, 'Docker Containerization Guide', 'Docker makes deployment easier. Let''s learn how to containerize your applications...', '2024-12-28 11:30:00', 112),
(6, 2, 'Backpacking Southeast Asia on $50 a Day', 'An incredible journey through Thailand, Vietnam, and Cambodia. Budget tips and unmissable spots...', '2024-12-27 09:20:00', 201),
(9, 4, 'Work-Life Balance in Tech', 'Burnout is real. Here''s how to maintain work-life balance while working in tech...', '2024-12-26 13:00:00', 156),
(5, 6, 'Best Indie Games Nobody Played', 'Hidden gem games that deserve more attention. These indie titles are absolutely incredible...', '2024-12-25 15:30:00', 145),
(10, 3, 'Vegan Cooking Basics', 'Getting started with plant-based cooking. Simple recipes and ingredient swaps...', '2024-12-24 10:45:00', 98),
(3, 1, 'Git Workflow Mastery', 'Master Git branching strategies, rebasing, and collaboration. A complete guide...', '2024-12-23 12:15:00', 167),
(8, 2, 'Iceland: Land of Fire and Ice', 'Exploring Iceland''s waterfalls, glaciers, and hot springs. A photographer''s paradise...', '2024-12-22 08:30:00', 189),
(4, 1, 'TypeScript Advanced Types', 'Deep dive into TypeScript generics, mapped types, and conditional types...', '2024-12-21 14:20:00', 143),
(5, 4, 'Building Passive Income Streams', 'Different ways to build passive income. From blogging to digital products...', '2024-12-20 10:00:00', 176);


-- Data for Name: Comments; Type: TABLE DATA; Schema: public; Owner: -
-- Note: parent_comment_id is NULL for top-level comments, references another comment_id for replies

INSERT INTO Comments (post_id, user_id, content, created_at, likes_count, parent_comment_id) VALUES
(1, 5, 'Great tutorial! Really helpful for beginners.', '2025-01-15 11:20:00', 2, NULL),
(1, 7, 'Could you explain transactions more? Great post though!', '2025-01-15 13:00:00', 1, NULL),
(2, 3, 'ES6 is amazing. This was a perfect explanation!', '2025-01-14 15:10:00', 12, NULL),
(2, 6, 'I still struggle with async/await, need more examples.', '2025-01-14 16:45:00', 3, NULL),
(3, 4, 'Tokyo is beautiful! Love the photos you shared.', '2025-01-13 10:30:00', 15, NULL),
(3, 10, 'Planning my own trip there, this is so helpful!', '2025-01-13 12:00:00', 9, NULL),
(4, 5, 'Making this tonight! Looks delicious.', '2025-01-12 19:20:00', 7, NULL),
(4, 9, 'Any vegetarian versions?', '2025-01-12 20:00:00', 2, NULL),
(5, 3, 'Excellent guide for building APIs. Will follow this!', '2025-01-11 12:10:00', 18, NULL),
(5, 8, 'What about authentication? Would love to see that.', '2025-01-11 14:30:00', 6, NULL),
(6, 7, 'Agreed! 2024 had amazing games.', '2025-01-10 17:45:00', 11, NULL),
(6, 4, 'Where''s Elden Ring 2? That should be #1!', '2025-01-10 18:20:00', 8, NULL),
(7, 3, 'This changed my mornings. Thanks!', '2025-01-09 08:15:00', 14, NULL),
(7, 6, 'Trying this tomorrow, fingers crossed!', '2025-01-09 09:00:00', 4, NULL),
(8, 4, 'Normalization is so important. Great breakdown!', '2025-01-08 14:40:00', 10, NULL),
(9, 5, 'Saving this for my Paris trip next month!', '2025-01-07 11:30:00', 12, NULL),
(10, 3, 'Starting my startup next year, this is gold!', '2025-01-06 16:20:00', 9, NULL),
(11, 7, 'These recipes are game-changing!', '2025-01-05 13:10:00', 11, NULL),
(12, 6, 'Finally understanding ML concepts. Thank you!', '2025-01-04 15:30:00', 16, NULL),
(13, 5, 'Minimalism resonates with me. Great post!', '2025-01-03 09:45:00', 7, NULL),
(14, 3, 'Hooks are so much better than class components!', '2025-01-02 12:20:00', 9, NULL),
(14, 7, 'Can you do a video tutorial on this?', '2025-01-02 13:00:00', 4, NULL),
(15, 4, 'Budget travel is the best way to explore!', '2025-01-01 09:45:00', 13, NULL),
(15, 5, 'These tips saved me so much money!', '2025-01-01 10:30:00', 8, NULL),
(16, 3, 'Web scraping is so powerful. Nice tutorial!', '2024-12-31 10:45:00', 10, NULL),
(16, 6, 'Ethics matter. Good job emphasizing responsible scraping.', '2024-12-31 11:30:00', 7, NULL),
(17, 5, 'This is exactly what I needed for my business!', '2024-12-30 14:30:00', 12, NULL),
(17, 9, 'Do you have recommendations for caching strategies?', '2024-12-30 15:15:00', 5, NULL),
(18, 4, 'Finally a perfect recipe! Made these yesterday.', '2024-12-29 17:20:00', 11, NULL),
(18, 8, 'Brown butter is the secret ingredient!', '2024-12-29 18:00:00', 6, NULL),
(19, 3, 'Docker simplified everything for our team.', '2024-12-28 12:00:00', 14, NULL),
(19, 7, 'Great explanation of images vs containers!', '2024-12-28 13:15:00', 8, NULL),
(20, 4, 'Booking my trip based on your suggestions!', '2024-12-27 09:50:00', 16, NULL),
(20, 6, 'The photography is absolutely stunning.', '2024-12-27 10:30:00', 10, NULL),
(21, 3, 'This resonates deeply. Burnout is real in tech.', '2024-12-26 13:30:00', 13, NULL),
(21, 8, 'What specific strategies have helped you most?', '2024-12-26 14:15:00', 6, NULL),
(22, 5, 'Adding these to my wishlist right now!', '2024-12-25 16:00:00', 11, NULL),
(22, 7, 'Stardew Valley should be on this list!', '2024-12-25 16:45:00', 9, NULL),
(23, 4, 'Plant-based cooking is easier than I thought!', '2024-12-24 11:15:00', 9, NULL),
(23, 6, 'Do you have a nutrition guide to go with these?', '2024-12-24 12:00:00', 4, NULL),
(24, 5, 'Finally understanding rebase vs merge!', '2024-12-23 12:45:00', 15, NULL),
(24, 7, 'Every developer should read this.', '2024-12-23 13:30:00', 10, NULL),
(25, 3, 'Iceland is on my bucket list now!', '2024-12-22 09:00:00', 14, NULL),
(25, 6, 'Your photos are inspiring. Great storytelling!', '2024-12-22 10:15:00', 11, NULL),
(1, 3, 'I agree with the tutorial approach!', '2025-01-15 11:45:00', 2, 1),
(1, 4, 'Great point about transactions!', '2025-01-15 13:30:00', 1, 2);

-- Data for Name: Comment_Likes; Type: TABLE DATA; Schema: public; Owner: -

INSERT INTO Comment_Likes (comment_id, user_id, created_at) VALUES
(1, 3, '2025-01-15 11:30:00'),
(1, 4, '2025-01-15 11:40:00'),
(2, 5, '2025-01-15 13:15:00'),
(3, 4, '2025-01-14 15:20:00'),
(3, 7, '2025-01-14 15:35:00'),
(4, 3, '2025-01-14 17:00:00'),
(5, 6, '2025-01-13 10:45:00'),
(6, 5, '2025-01-13 12:15:00'),
(6, 7, '2025-01-13 12:30:00'),
(7, 3, '2025-01-12 19:30:00'),
(8, 5, '2025-01-12 20:15:00'),
(9, 4, '2025-01-11 12:25:00'),
(10, 5, '2025-01-11 14:45:00'),
(11, 5, '2025-01-10 18:00:00'),
(12, 3, '2025-01-10 18:30:00'),
(13, 4, '2025-01-09 08:30:00'),
(14, 5, '2025-01-09 09:15:00'),
(15, 3, '2025-01-08 14:50:00'),
(16, 5, '2025-01-07 11:45:00'),
(17, 4, '2025-01-06 16:35:00'),
(18, 5, '2025-01-05 13:25:00'),
(19, 4, '2025-01-04 15:45:00'),
(20, 4, '2025-01-03 10:00:00'),
(21, 4, '2025-01-02 12:35:00'),
(22, 3, '2025-01-02 13:15:00'),
(23, 5, '2025-01-01 10:00:00'),
(24, 5, '2024-12-23 13:00:00'),
(25, 4, '2024-12-22 09:30:00'),
(47, 5, '2025-01-15 12:00:00'),
(48, 4, '2025-01-15 13:45:00');

-- Data for Name: Post_Tags; Type: TABLE DATA; Schema: public; Owner: -

INSERT INTO Post_Tags (post_id, tag_id) VALUES
(1, 1), (1, 2), (1, 13),
(2, 1), (2, 9), (2, 10),
(3, 7), (3, 6),
(4, 14), (4, 1),
(5, 1), (5, 9), (5, 12),
(6, 5), (6, 8),
(7, 8), (7, 4), (7, 15),
(8, 13), (8, 3), (8, 4),
(9, 7), (9, 6),
(10, 5), (10, 8),
(11, 14), (11, 15), (11, 16),
(12, 1), (12, 3), (12, 2),
(13, 4), (13, 6),
(14, 1), (14, 9), (14, 11),
(15, 7), (15, 4),
(16, 1), (16, 9), (16, 11),
(17, 5), (17, 8), (17, 4),
(18, 14), (18, 3),
(19, 1), (19, 12), (19, 9),
(20, 7), (20, 5), (20, 6),
(21, 8), (21, 4), (21, 15),
(22, 5), (22, 8),
(23, 14), (23, 16), (23, 3),
(24, 1), (24, 9), (24, 4),
(25, 7), (25, 6), (25, 5),
(26, 1), (26, 3), (26, 10);

-- Data for Name: Likes; Type: TABLE DATA; Schema: public; Owner: -

INSERT INTO Likes (post_id, user_id, created_at) VALUES
(1, 3, '2025-01-15 10:45:00'),
(1, 4, '2025-01-15 11:15:00'),
(1, 5, '2025-01-15 11:30:00'),
(1, 6, '2025-01-15 12:00:00'),
(1, 7, '2025-01-15 12:30:00'),
(2, 3, '2025-01-14 15:00:00'),
(2, 4, '2025-01-14 15:20:00'),
(2, 5, '2025-01-14 15:45:00'),
(2, 6, '2025-01-14 16:00:00'),
(3, 4, '2025-01-13 10:20:00'),
(3, 5, '2025-01-13 11:00:00'),
(3, 7, '2025-01-13 11:30:00'),
(3, 8, '2025-01-13 12:00:00'),
(4, 3, '2025-01-12 19:00:00'),
(4, 5, '2025-01-12 19:30:00'),
(4, 6, '2025-01-12 20:00:00'),
(5, 3, '2025-01-11 11:50:00'),
(5, 4, '2025-01-11 12:00:00'),
(5, 6, '2025-01-11 13:00:00'),
(5, 7, '2025-01-11 14:00:00'),
(6, 3, '2025-01-10 16:40:00'),
(6, 5, '2025-01-10 17:00:00'),
(6, 7, '2025-01-10 17:30:00'),
(6, 8, '2025-01-10 18:00:00'),
(7, 3, '2025-01-09 07:30:00'),
(7, 4, '2025-01-09 08:00:00'),
(7, 5, '2025-01-09 08:30:00'),
(8, 3, '2025-01-08 13:30:00'),
(8, 4, '2025-01-08 14:00:00'),
(8, 6, '2025-01-08 14:30:00'),
(9, 4, '2025-01-07 10:50:00'),
(9, 5, '2025-01-07 11:00:00'),
(9, 7, '2025-01-07 11:30:00'),
(10, 3, '2025-01-06 15:40:00'),
(10, 5, '2025-01-06 16:00:00'),
(11, 4, '2025-01-05 12:15:00'),
(11, 6, '2025-01-05 12:45:00'),
(11, 7, '2025-01-05 13:00:00'),
(12, 3, '2025-01-04 14:20:00'),
(12, 5, '2025-01-04 15:00:00'),
(12, 7, '2025-01-04 15:45:00'),
(13, 3, '2025-01-03 08:45:00'),
(13, 5, '2025-01-03 09:30:00'),
(14, 4, '2025-01-02 12:00:00'),
(14, 6, '2025-01-02 13:00:00'),
(14, 7, '2025-01-02 14:00:00'),
(15, 3, '2025-01-01 09:30:00'),
(15, 4, '2025-01-01 10:00:00'),
(15, 5, '2025-01-01 10:30:00'),
(16, 3, '2024-12-31 10:30:00'),
(16, 4, '2024-12-31 11:00:00'),
(16, 5, '2024-12-31 11:30:00'),
(16, 6, '2024-12-31 12:00:00'),
(17, 3, '2024-12-30 14:15:00'),
(17, 4, '2024-12-30 14:45:00'),
(17, 5, '2024-12-30 15:00:00'),
(17, 6, '2024-12-30 15:30:00'),
(17, 7, '2024-12-30 16:00:00'),
(18, 4, '2024-12-29 17:00:00'),
(18, 5, '2024-12-29 17:30:00'),
(18, 6, '2024-12-29 18:15:00'),
(19, 3, '2024-12-28 11:45:00'),
(19, 4, '2024-12-28 12:15:00'),
(19, 5, '2024-12-28 12:45:00'),
(19, 6, '2024-12-28 13:00:00'),
(20, 3, '2024-12-27 09:35:00'),
(20, 4, '2024-12-27 10:00:00'),
(20, 5, '2024-12-27 10:15:00'),
(20, 6, '2024-12-27 10:45:00'),
(20, 7, '2024-12-27 11:00:00'),
(21, 3, '2024-12-26 13:15:00'),
(21, 5, '2024-12-26 13:45:00'),
(21, 7, '2024-12-26 14:00:00'),
(21, 8, '2024-12-26 14:30:00'),
(22, 3, '2024-12-25 15:45:00'),
(22, 4, '2024-12-25 16:15:00'),
(22, 6, '2024-12-25 16:45:00'),
(23, 4, '2024-12-24 11:00:00'),
(23, 5, '2024-12-24 11:30:00'),
(23, 6, '2024-12-24 12:15:00'),
(24, 3, '2024-12-23 12:30:00'),
(24, 4, '2024-12-23 12:50:00'),
(24, 6, '2024-12-23 13:15:00'),
(24, 7, '2024-12-23 13:45:00'),
(25, 3, '2024-12-22 08:45:00'),
(25, 4, '2024-12-22 09:15:00'),
(25, 5, '2024-12-22 09:45:00'),
(25, 6, '2024-12-22 10:00:00'),
(25, 7, '2024-12-22 10:30:00'),
(26, 3, '2024-12-21 14:30:00'),
(26, 4, '2024-12-21 15:00:00'),
(26, 5, '2024-12-21 15:15:00');

-- Data for Name: Followers; Type: TABLE DATA; Schema: public; Owner: -

INSERT INTO Followers (follower_id, followed_id) VALUES
(3, 5), (3, 6), (3, 7),
(4, 5), (4, 6), (4, 8),
(5, 3), (5, 7), (5, 9),
(6, 3), (6, 5), (6, 10),
(7, 3), (7, 5), (7, 8),
(8, 3), (8, 5), (8, 6),
(9, 5), (9, 7), (9, 10),
(10, 3), (10, 5), (10, 6);
