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
    role_id integer references Roles(role_id),
    email varchar(255) unique not null,
    username varchar(255) not null,
    birthdate date,
    password varchar(255) not null
);

CREATE TABLE Posts (
    post_id serial primary key,
    user_id integer references Users(user_id),
    category_id integer references Categories(category_id),
    title text not null,
    content text not null,
    created_at timestamp default current_timestamp,
    likes_count integer default 0
);

CREATE TABLE Comments (
    comment_id serial primary key,
    post_id integer references Posts(post_id),
    user_id integer references Users(user_id),
    content text not null,
    created_at timestamp default current_timestamp,
    likes_count integer default 0
);

CREATE TABLE Post_Tags (
    tag_id integer references Tags(tag_id),
    post_id integer references Posts(post_id),
    primary key (post_id, tag_id)
);

CREATE TABLE Followers (
    follower_id integer references Users(user_id),
    followed_id integer references Users(user_id),
    check (followed_id != follower_id),
    primary key (follower_id, followed_id)
);

CREATE TABLE Likes (
    like_id serial primary key,
    post_id integer references Posts(post_id),
    user_id integer references Users(user_id),
    created_at timestamp default current_timestamp,
    unique(post_id, user_id)
);

ALTER TABLE Posts 
  ADD CONSTRAINT fk_posts_user FOREIGN KEY (user_id) 
  REFERENCES Users(user_id) ON DELETE CASCADE;

ALTER TABLE Posts 
  ADD CONSTRAINT fk_posts_category FOREIGN KEY (category_id) 
  REFERENCES Categories(category_id) ON DELETE SET NULL;

ALTER TABLE Comments 
  ADD CONSTRAINT fk_comments_post FOREIGN KEY (post_id) 
  REFERENCES Posts(post_id) ON DELETE CASCADE;

ALTER TABLE Comments 
  ADD CONSTRAINT fk_comments_user FOREIGN KEY (user_id) 
  REFERENCES Users(user_id) ON DELETE CASCADE;

ALTER TABLE Likes 
  ADD CONSTRAINT fk_likes_post FOREIGN KEY (post_id) 
  REFERENCES Posts(post_id) ON DELETE CASCADE;

ALTER TABLE Likes 
  ADD CONSTRAINT fk_likes_user FOREIGN KEY (user_id) 
  REFERENCES Users(user_id) ON DELETE CASCADE;

ALTER TABLE Post_Tags 
  ADD CONSTRAINT fk_post_tags_post FOREIGN KEY (post_id) 
  REFERENCES Posts(post_id) ON DELETE CASCADE;

ALTER TABLE Post_Tags 
  ADD CONSTRAINT fk_post_tags_tag FOREIGN KEY (tag_id) 
  REFERENCES Tags(tag_id) ON DELETE CASCADE;

ALTER TABLE Followers 
  ADD CONSTRAINT fk_followers_follower FOREIGN KEY (follower_id) 
  REFERENCES Users(user_id) ON DELETE CASCADE;

ALTER TABLE Followers 
  ADD CONSTRAINT fk_followers_followed FOREIGN KEY (followed_id) 
  REFERENCES Users(user_id) ON DELETE CASCADE;

ALTER TABLE Posts ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE Comments ALTER COLUMN post_id SET NOT NULL;
ALTER TABLE Comments ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE Likes ALTER COLUMN post_id SET NOT NULL;
ALTER TABLE Likes ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE Followers ALTER COLUMN follower_id SET NOT NULL;
ALTER TABLE Followers ALTER COLUMN followed_id SET NOT NULL;

ALTER TABLE Followers 
  ADD CONSTRAINT check_not_self_follow CHECK (followed_id != follower_id);

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
COMMENT ON COLUMN Posts.created_at IS 'Automatically set to current timestamp on creation';
COMMENT ON COLUMN Comments.created_at IS 'Automatically set to current timestamp on creation';
COMMENT ON COLUMN Likes.created_at IS 'Timestamp of when user liked the post';

CREATE INDEX idx_posts_user_id ON Posts(user_id);
CREATE INDEX idx_posts_category_id ON Posts(category_id);
CREATE INDEX idx_comments_post_id ON Comments(post_id);
CREATE INDEX idx_comments_user_id ON Comments(user_id);
CREATE INDEX idx_post_tags_tag_id ON Post_Tags(tag_id);
CREATE INDEX idx_followers_follower_id ON Followers(follower_id);


-- Create a function that auto updates Categories post_count when new post with category is added
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