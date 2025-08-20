import UserModel from "../models/UserModel.js";
import MoodCheckIn from "../models/CheckIn.js";
import mongoose from "mongoose";

// GET /profile/summary
// req auth
export const getProfileSummary = async (req, res) => {
 try {
    const userId = req.user.sub;
    // basic user info (including email, excluding password)
    const user = await UserModel.findById(userId)
      .select('username email profilePicture');

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }
    
    // Get total number of check-ins for this user
    const totalCheckins = await MoodCheckIn.countDocuments({ userId });
    // Get top mood (most frequent emotion)
    const topMood = await getTopMood(userId);
    // Calculate check-in streak (consecutive days with at least one check-in)
    const checkinStreak = await calculateCheckinStreak(userId);
    // Get the 3 most recent checkins
    const recentCheckins = await MoodCheckIn.find({ userId })
      .select('emotion.name emotion.attributes timestamp')
      .sort({timestamp: -1})
      .limit(3)
      .lean();
    // Get weekly summary data
    const weeklySummary = await getWeeklySummary(userId);

    // Compile simplified profile summary
    const profileSummary = {
      username: user.username,
      email: user.email,
      profilePicture: user.profilePicture,
      totalCheckins,
      checkinStreak,
      topMood,
      recentCheckins,
      weeklySummary,
    };

    console.log(profileSummary);

    res.status(200).json({
      success: true,
      data: profileSummary
    });
  } catch (error) {
    console.error('Error fetching profile summary:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch profile summary',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

// GET /profile/analytics
// for stats
// average mood over past week, month, 3 months, year (DONE)
// avergae mood on each day of the week, (DONE)
// average mood when doing each logged activity, (DONE)
// average mood when with each logged person., (DONE)
// distribution of mood types (by attributes), (LATER)
// distribution of mood for 1-4 (LATER)
// there might be possible redundancy in the code, will overlook for now.

export const getMoodAnalytics = async (req, res) => {
  try {
    const userId = req.user.sub;
    const { period = '3months' } = req.query;

    // Calculate date range for the requested period
    const dateRange = getDateRange(period);
    if (!dateRange) {
      return res.status(400).json({
        success: false,
        message: 'Invalid period. Valid options: week, month, 3months, year, all'
      });
    }

    // Get average mood for the specific time period
    const averageMoodForPeriod = await getAverageMoodForPeriod(userId, period, dateRange);
    // Get average mood for each day of week
    const averageMoodByDayOfWeek = await getAverageMoodByDayOfWeek(userId, period, dateRange);
    // Get average mood based on each tagged activity
    const averageMoodByActivity = await getAverageMoodByContext(userId, period, dateRange, 'activity');
    // Get average mood based on each tagged person
    const averageMoodByPeople = await getAverageMoodByContext(userId, period, dateRange, 'people');    

    res.status(200).json({
      success: true,
      data: {
        period,
        dateRange: {
          start: dateRange.start,
          end: dateRange.end
        },
        averageMoodForPeriod,
        averageMoodByDayOfWeek,
        averageMoodByActivity,
        averageMoodByPeople,
      }
    });

  } catch (error) {
    console.error('Error fetching mood analytics:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch mood analytics',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

//Helper Get Top Mood Function
const getTopMood = async (userId) => {
  try {
    const topMoodResult = await MoodCheckIn.aggregate([
      { $match: { userId: new mongoose.Types.ObjectId(userId) } },
      {
        $group: {
          _id: '$emotion.name',
          count: { $sum: 1 },
          // Get the most recent attributes for this emotion
          latestAttributes: { $last: '$emotion.attributes' }
        }
      },
      { $sort: { count: -1 } },
      { $limit: 1 }
    ]);

    if (topMoodResult.length === 0) return null;

    return {
      name: topMoodResult[0]._id,
      count: topMoodResult[0].count,
      attributes: topMoodResult[0].latestAttributes
    };
  } catch (error) {
    console.error('Error getting top mood:', error);
    return null;
  }
};

//Helper Check in Streak calculator
const calculateCheckinStreak = async (userId) => {
  try {
    // Get all check-ins sorted by date (most recent first)
    const checkins = await MoodCheckIn.find({ userId })
      .select('timestamp')
      .sort({ timestamp: -1 })
      .lean();

    if (checkins.length === 0) return 0;

    let streak = 0;
    let currentDate = new Date();
    currentDate.setHours(0, 0, 0, 0); // Start from beginning of today

    // Check if there's a check-in today or yesterday to start the streak
    const mostRecentCheckin = new Date(checkins[0].timestamp);
    mostRecentCheckin.setHours(0, 0, 0, 0);
   
    const daysDiff = Math.floor((currentDate - mostRecentCheckin) / (1000 * 60 * 60 * 24));
   
    // If most recent check-in is more than 1 day old, streak is broken
    if (daysDiff > 1) return 0;
   
    // If most recent check-in was yesterday, start from yesterday
    if (daysDiff === 1) {
      currentDate.setDate(currentDate.getDate() - 1);
    }

    // Group check-ins by date
    const checkinsByDate = {};
    checkins.forEach(checkin => {
      const dateKey = new Date(checkin.timestamp).toDateString();
      checkinsByDate[dateKey] = true;
    });

    // Count consecutive days with check-ins
    while (checkinsByDate[currentDate.toDateString()]) {
      streak++;
      currentDate.setDate(currentDate.getDate() - 1);
    }

    return streak;
  } catch (error) {
    console.error('Error calculating check-in streak:', error);
    return 0;
  }
};

//Helper function to get weekly summary
const getWeeklySummary = async (userId) => {
  try {
    const period = 'week'; //hard coded to week
    // Calculate date range for the requested period
    const dateRange = getDateRange(period);
    if (!dateRange) {
      return res.status(400).json({
        success: false,
        message: 'Invalid period. Valid options: week, month, 3months, year, all'
      });
    }

    // Use aggregation pipeline to get both count and top mood for week
    const weeklyCheckins = await MoodCheckIn.aggregate([
      { $match: { 
          userId: new mongoose.Types.ObjectId(userId),
          timestamp: {
            $gte: dateRange.start,
            $lt: dateRange.end
          }
        }
      },
      {
        $facet: {
          // Get total count
          totalCount: [ { $count: "count" } ],
          // Get top emotion
          topEmotion: [
            {
              $group: {
                _id: '$emotion.name',
                count: { $sum: 1 },
              }
            },
            { $sort: { count: -1 } },
            { $limit: 1 }
          ]
        }
      }
    ]);

    const averageMoodForWeek = await getAverageMoodForPeriod(userId, period, dateRange);

    const weeklyCheckinsCount = weeklyCheckins[0].totalCount[0]?.count || 0;
    const topEmotionResult = weeklyCheckins[0].topEmotion;

    if (topEmotionResult.length === 0) {
      return {
        weeklyCheckinsCount,
        weeklyTopMood: null,
        averageMoodForWeek
      };
    }

    return {
      weeklyCheckinsCount,
      weeklyTopMood: {
        name: topEmotionResult[0]._id,
        count: topEmotionResult[0].count,
      },
      averageMoodForWeek
    };
  } catch (error) {
    console.error('Error getting weekly stats:', error);
    return {
      weeklyCheckinsCount: 0,
      weeklyTopMood: null
    };
  }
};

// Get average mood for a specific time period
// TODO: Possibly implement closest match emotion finder for avg mood, need a copy of every single mood and their values?
const getAverageMoodForPeriod = async (userId, period, dateRange) => {
  const match = {
    userId: new mongoose.Types.ObjectId(userId),
    ...(dateRange.start && { timestamp: { $gte: dateRange.start, $lt: dateRange.end } })
  };

  const avgMood = await MoodCheckIn.aggregate([
    { $match: match },
    {
      $group: {
        _id: null,
        avgPleasantness: { $avg: '$emotion.attributes.pleasantness' },
        avgIntensity: { $avg: '$emotion.attributes.intensity' },
        avgControl: { $avg: '$emotion.attributes.control' },
        avgClarity: { $avg: '$emotion.attributes.clarity' },
        totalCheckins: { $sum: 1 },
        emotions: { $push: '$emotion.name' }
      }
    }
  ]);

  if (avgMood.length === 0) {
    return {
      averageAttributes: {
        pleasantness: null,
        intensity: null,
        control: null,
        clarity: null
      },
      totalCheckins: 0,
      topEmotion: null,
      topEmotionCount: 0
    };
  }

  // Calculate most common emotion for this period
  const topEmotionData = calculateTopEmotion(avgMood[0].emotions);

  return {
    averageAttributes: {
      pleasantness: Math.round((avgMood[0].avgPleasantness || 0) * 100) / 100,
      intensity: Math.round((avgMood[0].avgIntensity || 0) * 100) / 100,
      control: Math.round((avgMood[0].avgControl || 0) * 100) / 100,
      clarity: Math.round((avgMood[0].avgClarity || 0) * 100) / 100
    },
    totalCheckins: avgMood[0].totalCheckins,
    topEmotion: topEmotionData?.name || null,
    topEmotionCount: topEmotionData?.count || 0
  };
};

// Get average mood for each day of the week within a time period
const getAverageMoodByDayOfWeek = async (userId, period, dateRange) => {
  const match = {
    userId: new mongoose.Types.ObjectId(userId),
    ...(dateRange.start && { timestamp: { $gte: dateRange.start, $lt: dateRange.end } })
  };

  const weeklyMoodData = await MoodCheckIn.aggregate([
    { $match: match },
    {
      $addFields: {
        dayOfWeek: { $dayOfWeek: '$timestamp' } //1=Sun, 2=Mon, etc.
      }
    },
    {
      $group: {
        _id: '$dayOfWeek',
        avgPleasantness: { $avg: '$emotion.attributes.pleasantness' },
        avgIntensity: { $avg: '$emotion.attributes.intensity' },
        avgControl: { $avg: '$emotion.attributes.control' },
        avgClarity: { $avg: '$emotion.attributes.clarity' },
        totalCheckins: { $sum: 1 },
        emotions: { $push: '$emotion.name' }
      }
    },
    {
      $sort: { _id: 1 } //Sort by day of week, sunday first
    }
  ]);

  // Map day numbers to day names
  const dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  
  // Initialize result with all days having null values
  const result = dayNames.map((dayName, index) => ({
    dayOfWeek: dayName,
    dayNumber: index + 1,
    averageAttributes: {
      pleasantness: null,
      intensity: null,
      control: null,
      clarity: null
    },
    totalCheckins: 0,
    topEmotion: null,
    topEmotionCount: 0
  }));

  // Fill in actual data where available
  weeklyMoodData.forEach(dayData => {
    const dayIndex = dayData._id - 1; // Convert 1-7 -> 0-6 for array indexing
    
    // Calculate most common emotion for this day
    const topEmotionData = calculateTopEmotion(dayData.emotions);

    result[dayIndex] = {
      dayOfWeek: dayNames[dayIndex],
      dayNumber: dayData._id,
      averageAttributes: {
        pleasantness: Math.round((dayData.avgPleasantness || 0) * 100) / 100,
        intensity: Math.round((dayData.avgIntensity || 0) * 100) / 100,
        control: Math.round((dayData.avgControl || 0) * 100) / 100,
        clarity: Math.round((dayData.avgClarity || 0) * 100) / 100
      },
      totalCheckins: dayData.totalCheckins,
      topEmotion: topEmotionData?.name || null,
      topEmotionCount: topEmotionData?.count || 0
    };
  });

  return result;
};

// Get average mood based on context (activities or people)
const getAverageMoodByContext = async (userId, period, dateRange, contextType) => {
  const contextField = contextType === 'activity' ? 'activities' : 'people';
  
  const match = {
    userId: new mongoose.Types.ObjectId(userId),
    ...(dateRange.start && { timestamp: { $gte: dateRange.start, $lt: dateRange.end } }),
    [contextField]: { $exists: true, $ne: [], $not: { $size: 0 } }
  };

  // Get context-specific data
  const contextMoodData = await MoodCheckIn.aggregate([
    { $match: match },
    { $unwind: `$${contextField}` },
    {
      $group: {
        _id: `$${contextField}`,
        avgPleasantness: { $avg: '$emotion.attributes.pleasantness' },
        avgIntensity: { $avg: '$emotion.attributes.intensity' },
        avgControl: { $avg: '$emotion.attributes.control' },
        avgClarity: { $avg: '$emotion.attributes.clarity' },
        totalCheckins: { $sum: 1 },
        emotions: { $push: '$emotion.name' }
      }
    },
    { $sort: { totalCheckins: -1 } }
  ]);

  // Get overall statistics for comparison
  const overallStats = await MoodCheckIn.aggregate([
    { $match: { userId: new mongoose.Types.ObjectId(userId), ...match } },
    {
      $group: {
        _id: null,
        totalCheckinsWithContext: { $sum: 1 },
        uniqueContexts: { $addToSet: `$${contextField}` }
      }
    }
  ]);

  const processedData = contextMoodData.map(contextData => {
    const topEmotionData = calculateTopEmotion(contextData.emotions);

    return {
      [contextType]: contextData._id,
      averageAttributes: {
        pleasantness: Math.round((contextData.avgPleasantness || 0) * 100) / 100,
        intensity: Math.round((contextData.avgIntensity || 0) * 100) / 100,
        control: Math.round((contextData.avgControl || 0) * 100) / 100,
        clarity: Math.round((contextData.avgClarity || 0) * 100) / 100
      },
      totalCheckins: contextData.totalCheckins,
      topEmotion: topEmotionData?.name || null,
      topEmotionCount: topEmotionData?.count || 0,
      percentageOfTotal: overallStats[0] ? 
        Math.round((contextData.totalCheckins / overallStats[0].totalCheckinsWithContext) * 10000) / 100 : 0
    };
  });

  return {
    contexts: processedData,
    summary: {
      totalUniqueContexts: overallStats[0] ? overallStats[0].uniqueContexts.flat().length : 0,
      totalCheckinsWithContext: overallStats[0] ? overallStats[0].totalCheckinsWithContext : 0
    }
  };
};

// Helper function to calculate most common emotion from array
const calculateTopEmotion = (emotions) => {
  if (!emotions || emotions.length === 0) return null;
  
  const emotionCounts = {};
  emotions.forEach(emotion => {
    emotionCounts[emotion] = (emotionCounts[emotion] || 0) + 1;
  });
  
  const topEmotion = Object.entries(emotionCounts)
    .sort(([,a], [,b]) => b - a)[0];
    
  return topEmotion ? { name: topEmotion[0], count: topEmotion[1] } : null;
};


// Helper function to calculate date ranges
const getDateRange = (period) => {
  const now = new Date();
  const end = new Date(now);
  end.setHours(23, 59, 59, 999); // EOD

  let start;
  
  switch (period) {
    case 'week':
      start = new Date(now);
      start.setDate(now.getDate() - 7);
      break;
    case 'month':
      start = new Date(now);
      start.setMonth(now.getMonth() - 1);
      break;
    case '3months':
      start = new Date(now);
      start.setMonth(now.getMonth() - 3);
      break;
    case 'year':
      start = new Date(now);
      start.setFullYear(now.getFullYear() - 1);
      break;
    case 'all':
      return { start: null, end: null }; 
    default:
      return null; // Invalid period
  }
  
  start.setHours(0, 0, 0, 0); 
  return { start, end };
};

