// src/App.tsx
import 'sanitize.css';
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
  SelectChangeEvent,
  IconButton,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Button,
} from "@mui/material";
import SettingsIcon from "@mui/icons-material/Settings";

// 型定義（特定ユーザー関連の型を削除）
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

interface PresenceSession {
  session_id: number;
  user_id: number;
  room_id: number;
  start_time: string;
  end_time: string | null;
  last_seen: string;
}

interface ServerOption {
  label: string;
  value: string;
}

const formatDate = (dateString: string): string => {
  if (!dateString) return "N/A";
  const date = new Date(dateString);
  return date.toISOString().replace('T', ' ').substring(0, 19);
};

const App: React.FC = () => {
  const isDevelopment = process.env.NODE_ENV === 'development';
  const storedServerUrl = isDevelopment
    ? localStorage.getItem('serverUrl') || "http://localhost:8010"
    : "https://elpis-m1.kajilab.dev";

  const [serverUrl, setServerUrl] = useState<string>(storedServerUrl);
  const [allPresenceHistory, setAllPresenceHistory] = useState<AllUsersPresenceDay[] | null>(null);
  const [currentOccupants, setCurrentOccupants] = useState<RoomOccupants[] | null>(null);
  const [loadingAllHistory, setLoadingAllHistory] = useState<boolean>(true);
  const [loadingOccupants, setLoadingOccupants] = useState<boolean>(true);
  const [errorAllHistory, setErrorAllHistory] = useState<string | null>(null);
  const [errorOccupants, setErrorOccupants] = useState<string | null>(null);
  const [selectedDate, setSelectedDate] = useState<string>("");
  const [settingsOpen, setSettingsOpen] = useState<boolean>(false);

  const serverOptions: ServerOption[] = [
    { label: "本番環境", value: "https://elpis-m1.kajilab.dev" },
    { label: "開発環境", value: "http://localhost:8010" },
  ];

  useEffect(() => {
    const fetchData = async () => {
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

      await Promise.all([fetchAllPresenceHistory(), fetchCurrentOccupants()]);
    };

    fetchData();
  }, [serverUrl, selectedDate]);

  const handleServerChange = (event: SelectChangeEvent<string>) => {
    const selectedUrl = event.target.value;
    setServerUrl(selectedUrl);
    if (isDevelopment) {
      localStorage.setItem('serverUrl', selectedUrl);
    }
    setSettingsOpen(false);
  };

  const handleDateChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    setSelectedDate(event.target.value);
  };

  const handleOpenSettings = () => {
    setSettingsOpen(true);
  };

  const handleCloseSettings = () => {
    setSettingsOpen(false);
  };

  return (
    <Container maxWidth="lg" sx={{ padding: "20px" }}>
      {/* ヘッダー */}
      <Box
        mb={4}
        display="flex"
        alignItems="center"
        justifyContent="space-between"
        flexWrap="wrap"
      >
        {/* 左側：タイトルと日付選択 */}
        <Box display="flex" alignItems="center" flexWrap="wrap">
          <Typography variant="h4" gutterBottom>
            在室履歴と現在の在室者情報
          </Typography>
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
            sx={{ width: 200, ml: { xs: 0, sm: 2 }, mt: { xs: 2, sm: 0 } }}
          />
        </Box>

        {/* 右側：設定ボタン */}
        <Box>
          <IconButton
            color="primary"
            aria-label="settings"
            onClick={handleOpenSettings}
            size="large"
          >
            <SettingsIcon />
          </IconButton>
          <Dialog open={settingsOpen} onClose={handleCloseSettings}>
            <DialogTitle>サーバー設定</DialogTitle>
            <DialogContent>
              <FormControl fullWidth variant="outlined" size="small" sx={{ mt: 2 }}>
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
            </DialogContent>
            <DialogActions>
              <Button onClick={handleCloseSettings}>キャンセル</Button>
            </DialogActions>
          </Dialog>
        </Box>
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
                {formatDate(day.date)}
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
                              {formatDate(session.start_time)}
                            </TableCell>
                            <TableCell>
                              {session.end_time
                                ? formatDate(session.end_time)
                                : "N/A"}
                            </TableCell>
                            <TableCell>
                              {formatDate(session.last_seen)}
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
                            secondary={`最終確認時間: ${formatDate(
                              occupant.last_seen
                            )}`}
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
