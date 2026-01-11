-- PostgreSQL database dump - DENORMALIZED VERSION
-- This denormalized schema combines related tables to reduce joins and improve query performance

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET default_tablespace = '';
SET default_with_oids = false;

--- drop tables

DROP TABLE IF EXISTS Post_Likes;
DROP TABLE IF EXISTS User_Followers;
DROP TABLE IF EXISTS Post_Comments;
DROP TABLE IF EXISTS Posts_Extended;

-- Name: Posts_Extended; Type: TABLE; Schema: public; Owner: -; Tablespace: 
-- Denormalized table combining Posts, Users, Categories, and Roles

CREATE TABLE Posts_Extended (
    post_id serial primary key,
    user_id integer not null,
    username varchar(255) not null,
    email varchar(255) not null,
    role_id integer not null,
    role_name varchar(255),
    category_id integer,
    category_name varchar(255),
    title text not null,
    content text not null,
    created_at timestamp default current_timestamp,
    likes_count integer default 0,
    tags_list text, -- comma-separated tag names or JSON array
    post_count_at_category integer default 0
);

-- Name: Post_Comments; Type: TABLE; Schema: public; Owner: -; Tablespace: 
-- Denormalized table combining Comments, Users, and related Post info

CREATE TABLE Post_Comments (
    comment_id serial primary key,
    post_id integer not null,
    post_title text,
    user_id integer not null,
    commenter_username varchar(255) not null,
    commenter_email varchar(255) not null,
    content text not null,
    created_at timestamp default current_timestamp,
    likes_count integer default 0
);

-- Name: Post_Likes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
-- Denormalized table combining Likes with Post and User info

CREATE TABLE Post_Likes (
    like_id serial primary key,
    post_id integer not null,
    post_title text,
    post_author_id integer,
    post_author_username varchar(255),
    user_id integer not null,
    liker_username varchar(255) not null,
    liker_email varchar(255) not null,
    created_at timestamp default current_timestamp
);

-- Name: User_Followers; Type: TABLE; Schema: public; Owner: -; Tablespace: 
-- Denormalized table combining Followers with User details

CREATE TABLE User_Followers (
    follower_id integer not null,
    follower_username varchar(255) not null,
    follower_email varchar(255) not null,
    followed_id integer not null,
    followed_username varchar(255) not null,
    followed_email varchar(255) not null,
    followed_at timestamp default current_timestamp,
    check (followed_id != follower_id),
    primary key (follower_id, followed_id)
);

-- Create indexes for denormalized tables

CREATE INDEX idx_posts_extended_user_id ON Posts_Extended(user_id);
CREATE INDEX idx_posts_extended_category_id ON Posts_Extended(category_id);
CREATE INDEX idx_posts_extended_created_at ON Posts_Extended(created_at);
CREATE INDEX idx_post_comments_post_id ON Post_Comments(post_id);
CREATE INDEX idx_post_comments_user_id ON Post_Comments(user_id);
CREATE INDEX idx_post_likes_post_id ON Post_Likes(post_id);
CREATE INDEX idx_post_likes_user_id ON Post_Likes(user_id);
CREATE INDEX idx_user_followers_follower_id ON User_Followers(follower_id);
CREATE INDEX idx_user_followers_followed_id ON User_Followers(followed_id);

-- Comments on denormalized tables

COMMENT ON TABLE Posts_Extended IS 'Denormalized posts table combining Posts, Users, Categories, and Roles to reduce joins';
COMMENT ON TABLE Post_Comments IS 'Denormalized comments table with embedded user and post information';
COMMENT ON TABLE Post_Likes IS 'Denormalized likes table with embedded post and user details';
COMMENT ON TABLE User_Followers IS 'Denormalized followers table with embedded user details for both follower and followed users';
COMMENT ON COLUMN Posts_Extended.tags_list IS 'Denormalized list of tag names as comma-separated values or JSON';
