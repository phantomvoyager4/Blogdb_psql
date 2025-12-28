DROP TABLE IF EXISTS Followers;
DROP TABLE IF EXISTS Post_Tags;
DROP TABLE IF EXISTS Comments;
DROP TABLE IF EXISTS Posts;
DROP TABLE IF EXISTS Tags;
DROP TABLE IF EXISTS Categories;
DROP TABLE IF EXISTS Users;

CREATE TABLE Users (
    user_id serial primary key not null,
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

CREATE TABLE Categories (
    category_id serial primary key,
    category varchar(255) unique not null,
    post_count integer default 0
);

CREATE TABLE Tags (
    tag_id serial primary key,
    tag_name varchar(255) unique not null
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

