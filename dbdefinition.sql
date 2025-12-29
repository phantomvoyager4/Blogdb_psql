DROP TABLE IF EXISTS Likes;
DROP TABLE IF EXISTS Followers;
DROP TABLE IF EXISTS Post_Tags;
DROP TABLE IF EXISTS Comments;
DROP TABLE IF EXISTS Posts;
DROP TABLE IF EXISTS Tags;
DROP TABLE IF EXISTS Categories;
DROP TABLE IF EXISTS Users;
DROP TABLE IF EXISTS Roles;

CREATE TABLE Roles (
    role_id serial primary key,
    role_name varchar(255) unique not null
);

CREATE TABLE Categories (
    category_id serial primary key,
    category varchar(255) unique not null,
    post_count integer default 0
);

CREATE TABLE Tags (
    tag_id serial primary key,
    tag_name varchar(255) unique not null
);

CREATE TABLE Users (
    user_id serial primary key not null,
    role_id integer not null references Roles(role_id),
    email varchar(255) unique not null,
    username varchar(255) not null,
    birthdate date,
    password varchar(255) not null
);

CREATE TABLE Posts (
    post_id serial primary key,
    user_id integer not null references Users(user_id) on delete cascade,
    category_id integer references Categories(category_id) on delete set null,
    title text not null,
    content text not null,
    created_at timestamp default current_timestamp,
    likes_count integer default 0
);

CREATE TABLE Comments (
    comment_id serial primary key,
    post_id integer not null references Posts(post_id) on delete cascade,
    user_id integer not null references Users(user_id) on delete cascade,
    content text not null,
    created_at timestamp default current_timestamp,
    likes_count integer default 0
);

CREATE TABLE Post_Tags (
    tag_id integer not null references Tags(tag_id) on delete cascade,
    post_id integer not null references Posts(post_id) on delete cascade,
    primary key (post_id, tag_id)
);

CREATE TABLE Followers (
    follower_id integer not null references Users(user_id) on delete cascade,
    followed_id integer not null references Users(user_id) on delete cascade,
    check (followed_id != follower_id),
    primary key (follower_id, followed_id)
);

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
CREATE INDEX idx_post_tags_tag_id ON Post_Tags(tag_id);
CREATE INDEX idx_followers_follower_id ON Followers(follower_id);

COMMENT ON TABLE Roles IS 'User roles for access control (Admin, Moderator, User)';
COMMENT ON TABLE Users IS 'User accounts with email, username, and assigned roles';
COMMENT ON TABLE Categories IS 'Blog post categories with auto-updated post count via trigger';
COMMENT ON TABLE Tags IS 'Tags for categorizing and organizing posts';
COMMENT ON TABLE Posts IS 'Blog posts with content, timestamps, and like counts';
COMMENT ON COLUMN Posts.likes_count IS 'Denormalized count; actual likes tracked in Likes table';
COMMENT ON TABLE Comments IS 'Comments on posts with user attribution and engagement metrics';
COMMENT ON TABLE Post_Tags IS 'Junction table linking posts to multiple tags (many-to-many)';
COMMENT ON TABLE Likes IS 'Tracks individual user likes on posts with timestamps';
COMMENT ON TABLE Followers IS 'User-to-user follow relationships for social features';
COMMENT ON COLUMN Users.role_id IS 'References user role for permission management';


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