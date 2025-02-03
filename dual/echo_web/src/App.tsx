// src/App.tsx
import 'sanitize.css'; // sanitize.css をインポート
import React, { useEffect, useState } from "react";
import {
  Container,
  Typography,
  CircularProgress,
  Alert,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Box,
  Grid,
  List,
  ListItem,
  ListItemText,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  TextField,
  SelectChangeEvent, // 追加
} from "@mui/material";

// 型定義（必要に応じて追加・修正してください）
interface PresenceSession {
  session_id: number;
  user_id: number;
  room_id: number;
  start_time: string;
  end_time: string | null;
  last_seen: string;
}

interface UserPresenceDay {
  date: string;
  sessions: PresenceSession[];
}

interface PresenceHistoryResponse {
  user_id: number;
  history: UserPresenceDay[];
}

interface AllUsersPresenceDay {
  date: string;
  users: UserPresenceDetail[];
}

interface UserPresenceDetail {
  user_id: number;
  sessions: PresenceSession[];
}

interface AllPresenceHistoryResponse {
  all_history: AllUsersPresenceDay[];
}

interface CurrentOccupant {
  user_id: string;
  last_seen: string;
}

interface RoomOccupants {
  room_id: number;
  room_name: string;
  occupants: CurrentOccupant[];
}

interface CurrentOccupantsResponse {
  rooms: RoomOccupants[];
}

// ユーザーオプションの型定義
interface UserOption {
  label: string;
  value: number;
}

const App: React.FC = () => {
  const isDevelopment = process.env.NODE_ENV === 'development';
  const storedServerUrl = isDevelopment
    ? localStorage.getItem('serverUrl') || "http://localhost:8011"
    : "https://elpis-m2.kajilab.dev";

  // ユーザーIDをステートとして管理（初期値は1）
  const [userId, setUserId] = useState<number>(1);

  const [serverUrl, setServerUrl] = useState<string>(storedServerUrl);
  const [presenceHistory, setPresenceHistory] = useState<UserPresenceDay[] | null>(null);
  const [allPresenceHistory, setAllPresenceHistory] = useState<AllUsersPresenceDay[] | null>(null);
  const [currentOccupants, setCurrentOccupants] = useState<RoomOccupants[] | null>(null);
  const [loadingHistory, setLoadingHistory] = useState<boolean>(true);
  const [loadingAllHistory, setLoadingAllHistory] = useState<boolean>(true);
  const [loadingOccupants, setLoadingOccupants] = useState<boolean>(true);
  const [errorHistory, setErrorHistory] = useState<string | null>(null);
  const [errorAllHistory, setErrorAllHistory] = useState<string | null>(null);
  const [errorOccupants, setErrorOccupants] = useState<string | null>(null);
  const [selectedDate, setSelectedDate] = useState<string>("");

  // サーバーURLの選択肢
  const serverOptions = [
    { label: "本番環境", value: "https://elpis-m2.kajilab.dev" },
    { label: "開発環境", value: "http://localhost:8011" },
  ];

  // ユーザーIDの選択肢（必要に応じてAPIから取得）
  // ここではサンプルとして固定のリストを使用
  const userOptions: UserOption[] = [
    { label: "ユーザー1", value: 1 },
    { label: "ユーザー2", value: 2 },
    { label: "ユーザー3", value: 3 },
    // 必要に応じて追加
  ];

  // サーバーURLが変更されたり、選択されたユーザーIDや日付が変更されたときにデータを再フェッチ
  useEffect(() => {
    // データを取得する関数
    const fetchData = async () => {
      // 特定ユーザーの在室履歴取得
      setLoadingHistory(true);
      setErrorHistory(null);
      setPresenceHistory(null);
      const presenceHistoryUrl = selectedDate
        ? `${serverUrl}/api/users/${userId}/presence_history?date=${selectedDate}`
        : `${serverUrl}/api/users/${userId}/presence_history`;

      const fetchPresenceHistory = async () => {
        try {
          const response = await fetch(presenceHistoryUrl, {
            headers: {
              Accept: "application/json",
            },
          });
          if (!response.ok) {
            throw new Error(`Error: ${response.status} ${response.statusText}`);
          }
          const data: PresenceHistoryResponse = await response.json();
          setPresenceHistory(data.history);
        } catch (error: any) {
          setErrorHistory(error.message);
        } finally {
          setLoadingHistory(false);
        }
      };

      // 全ユーザーの日毎の在室履歴取得
      setLoadingAllHistory(true);
      setErrorAllHistory(null);
      setAllPresenceHistory(null);
      const allPresenceHistoryUrl = selectedDate
        ? `${serverUrl}/api/presence_history?date=${selectedDate}`
        : `${serverUrl}/api/presence_history`;

      const fetchAllPresenceHistory = async () => {
        try {
          const response = await fetch(allPresenceHistoryUrl, {
            headers: {
              Accept: "application/json",
            },
          });
          if (!response.ok) {
            throw new Error(`Error: ${response.status} ${response.statusText}`);
          }
          const data: AllPresenceHistoryResponse = await response.json();
          setAllPresenceHistory(data.all_history);
        } catch (error: any) {
          setErrorAllHistory(error.message);
        } finally {
          setLoadingAllHistory(false);
        }
      };

      // 現在の在室者情報の取得
      setLoadingOccupants(true);
      setErrorOccupants(null);
      setCurrentOccupants(null);
      const fetchCurrentOccupants = async () => {
        try {
          const response = await fetch(`${serverUrl}/api/current_occupants`, {
            headers: {
              Accept: "application/json",
            },
          });
          if (!response.ok) {
            throw new Error(`Error: ${response.status} ${response.statusText}`);
          }
          const data: CurrentOccupantsResponse = await response.json();
          setCurrentOccupants(data.rooms);
        } catch (error: any) {
          setErrorOccupants(error.message);
        } finally {
          setLoadingOccupants(false);
        }
      };

      // 並行してデータを取得
      await Promise.all([fetchPresenceHistory(), fetchAllPresenceHistory(), fetchCurrentOccupants()]);
    };

    fetchData();
  }, [serverUrl, userId, selectedDate]); // userId を依存配列に追加

  // サーバー選択の変更ハンドラー
  const handleServerChange = (event: SelectChangeEvent<string>) => {
    const selectedUrl = event.target.value;
    setServerUrl(selectedUrl);
    if (isDevelopment) {
      localStorage.setItem('serverUrl', selectedUrl);
    }
  };

  // ユーザーID選択の変更ハンドラー
  const handleUserChange = (event: SelectChangeEvent<string>) => {
    const selectedUserId = Number(event.target.value);
    setUserId(selectedUserId);
  };

  // 日付選択ハンドラー
  const handleDateChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    setSelectedDate(event.target.value);
  };

  return (
    <Container maxWidth="lg" sx={{ padding: "20px" }}>
      <Box mb={4} display="flex" alignItems="center" justifyContent="space-between" flexWrap="wrap">
        <Typography variant="h4" gutterBottom>
          在室履歴と現在の在室者情報
        </Typography>
        {/* サーバー選択ドロップダウン */}
        <FormControl variant="outlined" size="small" sx={{ minWidth: 200, mr: 2, mt: { xs: 2, sm: 0 } }}>
          <InputLabel id="server-select-label">サーバー選択</InputLabel>
          <Select
            labelId="server-select-label"
            id="server-select"
            value={serverUrl}
            onChange={handleServerChange}
            label="サーバー選択"
          >
            {serverOptions.map((option) => (
              <MenuItem key={option.value} value={option.value}>
                {option.label}
              </MenuItem>
            ))}
          </Select>
        </FormControl>
        {/* ユーザーID選択ドロップダウン */}
        <FormControl variant="outlined" size="small" sx={{ minWidth: 150, mr: 2, mt: { xs: 2, sm: 0 } }}>
          <InputLabel id="user-select-label">ユーザーID</InputLabel>
          <Select
            labelId="user-select-label"
            id="user-select"
            value={userId.toString()} // 数値を文字列に変換
            onChange={handleUserChange}
            label="ユーザーID"
          >
            {userOptions.map((user) => (
              <MenuItem key={user.value} value={user.value.toString()}>
                {user.label}
              </MenuItem>
            ))}
          </Select>
        </FormControl>
        {/* 日付選択フィールド */}
        <TextField
          id="date"
          label="日付を選択"
          type="date"
          value={selectedDate}
          onChange={handleDateChange}
          InputLabelProps={{
            shrink: true,
          }}
          variant="outlined"
          size="small"
          sx={{ width: 200, mt: { xs: 2, sm: 0 } }}
        />
      </Box>

      {/* 特定ユーザーの在室履歴セクション */}
      <Box mb={6}>
        <Typography variant="h5" gutterBottom>
          特定ユーザーの在室履歴 (ユーザーID: {userId})
        </Typography>
        {loadingHistory ? (
          <Box display="flex" alignItems="center">
            <CircularProgress size={24} />
            <Typography variant="body1" ml={2}>
              在室履歴を取得中...
            </Typography>
          </Box>
        ) : errorHistory ? (
          <Alert severity="error">エラー: {errorHistory}</Alert>
        ) : presenceHistory && presenceHistory.length > 0 ? (
          presenceHistory.map((day) => (
            <Box key={day.date} mb={4}>
              <Typography variant="h6" gutterBottom>
                {day.date}
              </Typography>
              <TableContainer component={Paper} elevation={3}>
                <Table>
                  <TableHead>
                    <TableRow>
                      <TableCell>セッションID</TableCell>
                      <TableCell>ユーザーID</TableCell>
                      <TableCell>部屋ID</TableCell>
                      <TableCell>開始時間</TableCell>
                      <TableCell>終了時間</TableCell>
                      <TableCell>最終確認時間</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {day.sessions.map((session) => (
                      <TableRow key={session.session_id}>
                        <TableCell>{session.session_id}</TableCell>
                        <TableCell>{session.user_id}</TableCell>
                        <TableCell>{session.room_id}</TableCell>
                        <TableCell>
                          {new Date(session.start_time).toLocaleString()}
                        </TableCell>
                        <TableCell>
                          {session.end_time
                            ? new Date(session.end_time).toLocaleString()
                            : "N/A"}
                        </TableCell>
                        <TableCell>
                          {new Date(session.last_seen).toLocaleString()}
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </TableContainer>
            </Box>
          ))
        ) : (
          <Typography variant="body1">在室履歴が見つかりません。</Typography>
        )}
      </Box>

      {/* 全ユーザーの日毎の在室履歴セクション */}
      <Box mb={6}>
        <Typography variant="h5" gutterBottom>
          全ユーザーの日毎の在室履歴
        </Typography>
        {loadingAllHistory ? (
          <Box display="flex" alignItems="center">
            <CircularProgress size={24} />
            <Typography variant="body1" ml={2}>
              全ユーザーの在室履歴を取得中...
            </Typography>
          </Box>
        ) : errorAllHistory ? (
          <Alert severity="error">エラー: {errorAllHistory}</Alert>
        ) : allPresenceHistory && allPresenceHistory.length > 0 ? (
          allPresenceHistory.map((day) => (
            <Box key={day.date} mb={4}>
              <Typography variant="h6" gutterBottom>
                {day.date}
              </Typography>
              {day.users.map((user) => (
                <Box key={user.user_id} mb={2}>
                  <Typography variant="subtitle1">
                    ユーザーID: {user.user_id}
                  </Typography>
                  <TableContainer component={Paper} elevation={3}>
                    <Table>
                      <TableHead>
                        <TableRow>
                          <TableCell>セッションID</TableCell>
                          <TableCell>部屋ID</TableCell>
                          <TableCell>開始時間</TableCell>
                          <TableCell>終了時間</TableCell>
                          <TableCell>最終確認時間</TableCell>
                        </TableRow>
                      </TableHead>
                      <TableBody>
                        {user.sessions.map((session) => (
                          <TableRow key={session.session_id}>
                            <TableCell>{session.session_id}</TableCell>
                            <TableCell>{session.room_id}</TableCell>
                            <TableCell>
                              {new Date(session.start_time).toLocaleString()}
                            </TableCell>
                            <TableCell>
                              {session.end_time
                                ? new Date(session.end_time).toLocaleString()
                                : "N/A"}
                            </TableCell>
                            <TableCell>
                              {new Date(session.last_seen).toLocaleString()}
                            </TableCell>
                          </TableRow>
                        ))}
                      </TableBody>
                    </Table>
                  </TableContainer>
                </Box>
              ))}
            </Box>
          ))
        ) : (
          <Typography variant="body1">全ユーザーの在室履歴が見つかりません。</Typography>
        )}
      </Box>

      {/* 現在の在室者情報セクション */}
      <Box>
        <Typography variant="h5" gutterBottom>
          現在の在室者情報
        </Typography>
        {loadingOccupants ? (
          <Box display="flex" alignItems="center">
            <CircularProgress size={24} />
            <Typography variant="body1" ml={2}>
              現在の在室者情報を取得中...
            </Typography>
          </Box>
        ) : errorOccupants ? (
          <Alert severity="error">エラー: {errorOccupants}</Alert>
        ) : currentOccupants && currentOccupants.length > 0 ? (
          <Grid container spacing={4}>
            {currentOccupants.map((room) => (
              <Grid item xs={12} md={6} key={room.room_id}>
                <Paper elevation={3} sx={{ padding: "16px" }}>
                  <Typography variant="h6" gutterBottom>
                    {room.room_name} (ID: {room.room_id})
                  </Typography>
                  {room.occupants.length > 0 ? (
                    <List>
                      {room.occupants.map((occupant) => (
                        <ListItem key={occupant.user_id} disablePadding>
                          <ListItemText
                            primary={`ユーザーID: ${occupant.user_id}`}
                            secondary={`最終確認時間: ${new Date(
                              occupant.last_seen
                            ).toLocaleString()}`}
                          />
                        </ListItem>
                      ))}
                    </List>
                  ) : (
                    <Typography variant="body2">
                      現在在室者はいません。
                    </Typography>
                  )}
                </Paper>
              </Grid>
            ))}
          </Grid>
        ) : (
          <Typography variant="body1">
            現在の在室者情報が見つかりません。
          </Typography>
        )}
      </Box>
    </Container>
  );
};

export default App;
