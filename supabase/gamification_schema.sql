-- =====================================================
-- KINNECT GAMIFICATION SQL SCHEMA
-- Run this in Supabase SQL Editor
-- Scaled down for small user base testing
-- =====================================================

-- 1. Levels Table
CREATE TABLE IF NOT EXISTS levels (
  level INTEGER PRIMARY KEY,
  required_xp INTEGER NOT NULL,
  title TEXT NOT NULL,
  flame_color TEXT DEFAULT '#FF6B35'
);

-- Insert level data (scaled down XP)
INSERT INTO levels (level, required_xp, title, flame_color) VALUES
(1,  0,      'Kıvılcım',        '#FFB347'),
(2,  50,     'Küçük Alev',      '#FF8C42'),
(3,  120,    'Yanan Kor',       '#FF6B35'),
(4,  220,    'Meşale',          '#FF5722'),
(5,  360,    'Ateş Dansçısı',   '#F4511E'),
(6,  550,    'Alev Ustası',     '#E64A19'),
(7,  800,    'Volkan',          '#D84315'),
(8,  1100,   'Ateş Lordu',      '#BF360C'),
(9,  1500,   'Sönmez Ateş',     '#A52714'),
(10, 2000,   'Efsane Alevler',  '#8E0000')
ON CONFLICT (level) DO NOTHING;

-- 2. Achievements Table
CREATE TABLE IF NOT EXISTS achievements (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  category TEXT NOT NULL,
  condition_type TEXT NOT NULL,
  condition_value INTEGER NOT NULL,
  xp_reward INTEGER DEFAULT 50,
  rarity TEXT DEFAULT 'common'
);

-- Insert achievements (scaled down thresholds)
INSERT INTO achievements VALUES
-- Social (scaled: 100->10, 500->25, 1000->50, 5000->100)
('spark_master',     'Kıvılcım Ustası',    '10 takipçiye ulaş',         'social', 'followers', 10, 50, 'common'),
('flame_spreader',   'Alev Yayıcı',        '25 takipçiye ulaş',         'social', 'followers', 25, 100, 'rare'),
('inferno_king',     'Cehennem Kralı',     '50 takipçiye ulaş',         'social', 'followers', 50, 200, 'epic'),
('phoenix_legend',   'Anka Efsanesi',      '100 takipçiye ulaş',        'social', 'followers', 100, 500, 'legendary'),

-- Content (scaled: 10->5, 50->15, 200->30)
('first_spark',      'İlk Kıvılcım',       'İlk postunu paylaş',        'content', 'posts', 1, 25, 'common'),
('burning_voice',    'Yanan Ses',          '5 post paylaş',             'content', 'posts', 5, 50, 'common'),
('eternal_flame',    'Sönmeyen Ateş',      '15 post paylaş',            'content', 'posts', 15, 100, 'rare'),
('wildfire',         'Orman Yangını',      '30 post paylaş',            'content', 'posts', 30, 200, 'epic'),

-- Engagement (scaled: 50->10, 500->50, 2000->100)
('match_striker',    'Kibrit Çakan',       '10 postu alevle',           'engagement', 'likes_given', 10, 30, 'common'),
('arsonist',         'Kundakçı',           '50 postu alevle',           'engagement', 'likes_given', 50, 100, 'rare'),
('pyromaniac',       'Piromanyak',         '100 postu alevle',          'engagement', 'likes_given', 100, 250, 'epic'),

-- Streak (scaled: 30->14, 100->21)
('warming_up',       'Isınma Turu',        '3 gün üst üste aktif ol',   'streak', 'daily_streak', 3, 30, 'common'),
('on_fire',          'Ateştesin!',         '7 gün üst üste aktif ol',   'streak', 'daily_streak', 7, 75, 'common'),
('unstoppable_blaze','Durdurulamaz Alev',  '14 gün üst üste aktif ol',  'streak', 'daily_streak', 14, 150, 'rare'),
('eternal_ember',    'Sonsuz Kor',         '21 gün üst üste aktif ol',  'streak', 'daily_streak', 21, 300, 'legendary')
ON CONFLICT (id) DO NOTHING;

-- 3. User Progress Table
CREATE TABLE IF NOT EXISTS user_progress (
  user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  total_xp INTEGER DEFAULT 0,
  current_level INTEGER DEFAULT 1,
  daily_streak INTEGER DEFAULT 0,
  last_active_date DATE,
  daily_quest_1_id TEXT,
  daily_quest_1_progress INTEGER DEFAULT 0,
  daily_quest_2_id TEXT,
  daily_quest_2_progress INTEGER DEFAULT 0,
  daily_quest_3_id TEXT,
  daily_quest_3_progress INTEGER DEFAULT 0,
  daily_quests_reset_at TIMESTAMP,
  total_posts INTEGER DEFAULT 0,
  total_likes_given INTEGER DEFAULT 0,
  total_comments INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 4. User Achievements Table
CREATE TABLE IF NOT EXISTS user_achievements (
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  achievement_id TEXT REFERENCES achievements(id),
  unlocked_at TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (user_id, achievement_id)
);

-- 5. Auto-create user progress on profile creation
CREATE OR REPLACE FUNCTION create_user_progress()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_progress (user_id) VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_profile_created ON profiles;
CREATE TRIGGER on_profile_created
AFTER INSERT ON profiles
FOR EACH ROW EXECUTE FUNCTION create_user_progress();

-- 6. Add XP Function
CREATE OR REPLACE FUNCTION add_xp(
  p_user_id UUID,
  p_xp_amount INTEGER,
  p_action_type TEXT DEFAULT 'generic'
)
RETURNS JSON AS $$
DECLARE
  v_current_xp INTEGER;
  v_current_level INTEGER;
  v_new_xp INTEGER;
  v_new_level INTEGER;
  v_level_up BOOLEAN := FALSE;
  v_next_level_xp INTEGER;
BEGIN
  SELECT total_xp, current_level INTO v_current_xp, v_current_level
  FROM user_progress WHERE user_id = p_user_id;
  
  IF v_current_xp IS NULL THEN
    INSERT INTO user_progress (user_id, total_xp, current_level)
    VALUES (p_user_id, 0, 1);
    v_current_xp := 0;
    v_current_level := 1;
  END IF;
  
  v_new_xp := v_current_xp + p_xp_amount;
  
  SELECT COALESCE(MAX(level), 1) INTO v_new_level
  FROM levels WHERE required_xp <= v_new_xp;
  
  v_level_up := v_new_level > v_current_level;
  
  UPDATE user_progress 
  SET total_xp = v_new_xp, 
      current_level = v_new_level,
      updated_at = NOW()
  WHERE user_id = p_user_id;
  
  SELECT required_xp INTO v_next_level_xp 
  FROM levels WHERE level = v_new_level + 1;
  
  RETURN json_build_object(
    'success', TRUE,
    'new_xp', v_new_xp,
    'new_level', v_new_level,
    'level_up', v_level_up,
    'next_level_xp', COALESCE(v_next_level_xp, v_new_xp)
  );
END;
$$ LANGUAGE plpgsql;

-- 7. Post XP Trigger
CREATE OR REPLACE FUNCTION on_post_created()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM add_xp(NEW.user_id, 15, 'post');
  
  UPDATE user_progress 
  SET total_posts = total_posts + 1 
  WHERE user_id = NEW.user_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_post_xp ON posts;
CREATE TRIGGER trg_post_xp
AFTER INSERT ON posts
FOR EACH ROW EXECUTE FUNCTION on_post_created();

-- 8. Like XP Trigger
CREATE OR REPLACE FUNCTION on_like_created()
RETURNS TRIGGER AS $$
BEGIN
  -- 2 XP for giving like
  PERFORM add_xp(NEW.user_id, 2, 'like_given');
  
  -- 3 XP for post owner
  PERFORM add_xp(
    (SELECT user_id FROM posts WHERE id = NEW.post_id),
    3, 
    'like_received'
  );
  
  UPDATE user_progress 
  SET total_likes_given = total_likes_given + 1 
  WHERE user_id = NEW.user_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_like_xp ON likes;
CREATE TRIGGER trg_like_xp
AFTER INSERT ON likes
FOR EACH ROW EXECUTE FUNCTION on_like_created();

-- 9. Comment XP Trigger
CREATE OR REPLACE FUNCTION on_comment_created()
RETURNS TRIGGER AS $$
BEGIN
  -- 5 XP for commenting
  PERFORM add_xp(NEW.user_id, 5, 'comment');
  
  UPDATE user_progress 
  SET total_comments = total_comments + 1 
  WHERE user_id = NEW.user_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_comment_xp ON comments;
CREATE TRIGGER trg_comment_xp
AFTER INSERT ON comments
FOR EACH ROW EXECUTE FUNCTION on_comment_created();

-- 10. Enable RLS
ALTER TABLE user_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view all progress" ON user_progress FOR SELECT USING (true);
CREATE POLICY "Users can update own progress" ON user_progress FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can view all achievements" ON user_achievements FOR SELECT USING (true);
CREATE POLICY "System can insert achievements" ON user_achievements FOR INSERT WITH CHECK (true);

-- =====================================================
-- Run this SQL in Supabase SQL Editor to set up gamification
-- =====================================================
